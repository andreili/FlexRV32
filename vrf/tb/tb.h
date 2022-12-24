#pragma once
#include <verilated.h>
#include <verilated_fst_c.h>
#include <string>
#include <functional>

#define STRINGIFY_MACRO(x) STR(x)
#define STR(x) #x
#define EXPAND(x) x
#define CONCAT(n1, n2) STRINGIFY_MACRO(EXPAND(n1)EXPAND(n2))
#define CONCAT3(n1, n2, n3) STRINGIFY_MACRO(EXPAND(n1)EXPAND(n2)EXPAND(n3))

#define CAT(x, y) CAT_(x, y)
#define CAT_(x, y) x ## y

#define TOP_CLASS CAT(V,TOP_NAME)
#define TOP_NAME_STR STRINGIFY_MACRO(TOP_NAME)

#include CONCAT(TOP_CLASS,.h)

typedef std::function<int(uint64_t,TOP_CLASS*)> step_cb_t;

class TB
{
public:
    TB(const std::string name, int argc, char** argv);

    void init(step_cb_t on_step = nullptr);

    VerilatedContext* get_context() { return m_context; }
    TOP_CLASS* get_top() { return m_top; }

    int step();
    int run_steps(uint64_t steps);
    void finish();
private:
    VerilatedContext*   m_context;
    VerilatedFstC*      m_fst;
    std::string         m_log_name;
    TOP_CLASS*          m_top;
    step_cb_t           m_step_cb;

    void parse_args();
    void parse_args_trace();
};
