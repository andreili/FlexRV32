#include "tb.h"

TB::TB(const std::string name, int argc, char** argv)
{
    m_log_name = "logs_" + name;
    Verilated::mkdir(m_log_name.c_str());
    m_context = new VerilatedContext();
    m_context->debug(0);
    m_context->randReset(2);
    m_context->traceEverOn(true);
    m_context->commandArgs(argc, argv);
}

void TB::init(step_cb_t on_step)
{
    m_top = new TOP_CLASS(m_context, "TOP");
    parse_args();
    m_step_cb = on_step;
}

int TB::step()
{
    m_context->timeInc(1);
    uint64_t cur_time = m_context->time();
    int ret_val;
    if (m_fst != nullptr)
    {
        m_fst->dump(cur_time);
    }
    if (m_step_cb != nullptr)
    {
        ret_val = m_step_cb(cur_time, m_top);
    }
    else
    {
        ret_val = 0;
    }
    m_top->eval();
    return ret_val;
}

int TB::run_steps(uint64_t steps)
{
    for (uint64_t i=0 ; i<steps ; ++i)
    {
        int ret = step();
        if(ret != 0)
        {
            return ret;
        }
    }
    return 0;
}

void TB::finish()
{
    if (m_fst != nullptr)
    {
        m_fst->close();
    }
}

void TB::parse_args()
{
    parse_args_trace();
}

void TB::parse_args_trace()
{
    const char* arg = m_context->commandArgsPlusMatch("trace");
    if (strlen(arg) > 0)
    {
        m_fst = new VerilatedFstC();
        m_top->trace(m_fst, 99);
        m_fst->open((m_log_name + "/wave.fst").c_str());
    }
    else
    {
        m_fst = nullptr;
    }
}
