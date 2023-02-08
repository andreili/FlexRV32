#include <memory>
#include <chrono>
#include <ctime> 
#include <cstdlib>
#include "tb.h"

double sc_time_stamp() { return 0; }

#define TICK_TIME 2
#define TICK_PERIOD (TICK_TIME / 2)
#define SIM_TIME_MAX (1000*10)
#define SIM_TIME_MAX_TICK (TICK_TIME * SIM_TIME_MAX)

#define ROUNDS (10*1000)

int64_t time_max;

int on_step_cb(uint64_t time, TOP_CLASS* p_top)
{
    if ((time % TICK_PERIOD) == 0)
    {
        p_top->i_clk = !p_top->i_clk;
    }
    return 0;
}

bool check_div_rem(TB* tb)
{
    uint64_t op1, op2, div, rem, div_check, rem_check;
    TOP_CLASS* top = tb->get_top();
    top->i_op1_signed = 0;
    top->i_op2_signed = 0;
    printf("div/rem - unsigned/unsigned.\n");
    for (uint64_t round=0 ; round<=ROUNDS ; ++round)
    {
        op1 = std::rand();
        op2 = std::rand();
        top->i_op1 = op1;
        top->i_op2 = op2;
        tb->run_steps(2);
        if (op2 == 0)
        {
            div_check = 0;
            rem_check = 0;
        }
        else
        {
            div_check = op1 / op2;
            rem_check = op1 % op2;
        }
        div = top->o_div;
        rem = top->o_rem;
        if ((div != div_check) || (rem != rem_check))
        {
            printf("[%d] Check failed! %ld/%ld=%ld(%ld), expected %ld(%ld)\n",
                round, op1, op2, div, rem, div_check, rem_check);
            return false;
        }
    }
    int64_t op1s, divs, rems, divs_check, rems_check;
    top->i_op1_signed = 1;
    top->i_op2_signed = 0;
    printf("div/rem - signed/unsigned.\n");
    for (uint64_t round=0 ; round<=ROUNDS ; ++round)
    {
        op1s = (1 - std::rand());
        op2 = std::rand();
        top->i_op1 = op1s;
        top->i_op2 = op2;
        tb->run_steps(2);
        if (op2 == 0)
        {
            divs_check = 0;
            rems_check = 0;
        }
        else
        {
            divs_check = op1s / op2;
            rems_check = op1s % op2;
        }
        divs = top->o_div;
        rems = top->o_rem;
        if ((divs != divs_check) || (rems != rems_check))
        {
            printf("[%d] Check failed! %ld/%ld=%ld(%ld), expected %ld(%ld)\n",
                round, op1s, op2, divs, rems, divs_check, rems_check);
            return false;
        }
    }
    return true;
}

bool check_mul(TB* tb)
{
    uint64_t op1, op2, mul, mul_check;
    int64_t op1s, op2s, muls, muls_check;
    TOP_CLASS* top = tb->get_top();

    //return false;

    top->i_op1_signed = 0;
    top->i_op2_signed = 0;
    printf("mul - unsigned/unsigned.\n");
    for (uint64_t round=0 ; round<=ROUNDS ; ++round)
    {
        op1 = std::rand();
        op2 = std::rand();
        top->i_op1 = op1;
        top->i_op2 = op2;
        tb->run_steps(2);
        if (op2 == 0)
        {
            mul_check = 0;
        }
        else
        {
            mul_check = op1 * op2;
        }
        mul = top->o_mul;
        if (mul != mul_check)
        {
            printf("[%d] Check failed! %ld*%ld=%+ld, expected %+ld\n",
                round, op1, op2, mul, mul_check);
            return false;
        }
    }
    top->i_op1_signed = 1;
    top->i_op2_signed = 0;
    printf("mul - signed/unsigned.\n");
    for (uint64_t round=0 ; round<=ROUNDS ; ++round)
    {
        op1s = (1 - std::rand());
        op2 = std::rand();
        top->i_op1 = op1s;
        top->i_op2 = op2;
        tb->run_steps(2);
        if (op2 == 0)
        {
            muls_check = 0;
        }
        else
        {
            muls_check = op1s * op2;
        }
        muls = top->o_mul;
        if (muls != muls_check)
        {
            printf("[%d] Check failed! %ld*%ld=%ld, expected %ld\n",
                round, op1s, op2, muls, muls_check);
            return false;
        }
    }
    top->i_op1_signed = 1;
    top->i_op2_signed = 1;
    printf("mul - signed/signed.\n");
    for (uint64_t round=0 ; round<=ROUNDS ; ++round)
    {
        op1s = (1 - std::rand());
        op2s = (1 - std::rand());
        top->i_op1 = op1s;
        top->i_op2 = op2s;
        tb->run_steps(2);
        if (op2s == 0)
        {
            muls_check = 0;
        }
        else
        {
            muls_check = op1s * op2s;
        }
        muls = top->o_mul;
        if (muls != muls_check)
        {
            printf("[%d] Check failed! %ld*%ld=%ld, expected %ld\n",
                round, op1s, op2s, muls, muls_check);
            return false;
        }
    }
    return true;
}

int main(int argc, char** argv, char** env)
{
    TB* tb = new TB(TOP_NAME_STR, argc, argv);
    tb->init(on_step_cb);
    TOP_CLASS* top = tb->get_top();

    const char* cycles_str = tb->get_context()->commandArgsPlusMatch("cycles");
    time_max = -1;
    if (strlen(cycles_str) > 8)
    {
        cycles_str += 8;
        time_max = atoi(cycles_str);
    }
    auto start = std::chrono::system_clock::now();
    int ret = -1;
    if (check_mul(tb) && check_div_rem(tb))
    {
        ret = 0;
    }
    auto end = std::chrono::system_clock::now();
    std::chrono::duration<double> elapsed_seconds = end-start;

    printf("Simulation time: %.3f(s)\n", elapsed_seconds);

    tb->finish();
    top->final();
#if VM_COVERAGE
    //tb->get_context()->coveragep()->write(COV_FN);
#endif
    return 0;//ret;
}
