"""Phase 15: two real local Docker DB sessions, no credentials.

Run after reset; reset afterwards removes committed synthetic salary records.
"""
import sys
import uuid

sys.dont_write_bytecode = True
from inventory_concurrency_test import auth, overlap, run


def save(month, revision, amount, key=None):
    return ("select public.save_salary('30000000-0000-4000-8000-000000000002',"
            f"'{month}',{amount},0,'Synthetic race',{revision},'{key or uuid.uuid4()}');")


def stale(sql):
    return ("do $test$ begin begin " + sql.replace('select public.', 'perform public.') +
            "raise exception 'Unexpected salary overwrite'; exception when serialization_failure then null; end; end $test$;")


def main():
    assert run('select count(*) from private.salary_changes;') == '0', 'Fresh reset required'
    overlap(auth(7) + save('2099-01-01', -1, 100),
            auth(7) + stale(save('2099-01-01', -1, 200)))
    assert run("select salary_kurus from public.employee_salary_records where period='2099-01-01';") == '100'
    print('PASS 1: concurrent create has one winner; no silent overwrite')
    overlap(auth(7) + save('2099-01-01', 0, 200),
            auth(7) + stale(save('2099-01-01', 0, 300)))
    assert run("select salary_kurus||'|'||revision from public.employee_salary_records where period='2099-01-01';") == '200|1'
    print('PASS 2: stale concurrent correction rejected')
    request = save('2099-02-01', -1, 100, uuid.uuid4())
    a, b = overlap(auth(7) + request, auth(7) + request)
    assert a == b
    assert run('select count(*) from private.salary_changes;') == '3'
    assert run("select count(*) from public.audit_logs where action='salary_changed';") == '3'
    print('PASS 3: concurrent same-key retry returns one record/history/audit')
    print('3/3 PASS; reset --local removes committed synthetic records')


if __name__ == '__main__':
    main()
