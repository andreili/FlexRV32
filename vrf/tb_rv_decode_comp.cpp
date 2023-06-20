#include <memory>
#include <chrono>
#include <ctime> 
#include <iomanip>
#include <fstream>
#include <fmt/format.h>
#include <jsoncpp/json/json.h>
#include "tb.h"

double sc_time_stamp() { return 0; }

#define TICK_TIME 10
#define TICK_PERIOD (TICK_TIME / 2)
#define SIM_TIME_MAX (1000*10)
#define SIM_TIME_MAX_TICK (TICK_TIME * SIM_TIME_MAX)

#define SIM_PULSE_DELTA 1000000

uint32_t prev_marker;
bool initialized;

Json::Value json_cmp;
Json::Value json_res;

int on_step_cb(uint64_t time, TOP_CLASS* p_top)
{
    if ((time % SIM_PULSE_DELTA) == 0)
    {
        std::cout << "SIM: running, time" << time << std::endl;
    }
    if ((time % 2) == 0)
    {
        int idx = json_res.size();
        uint32_t data_cmp;
        std::stringstream ss;
        ss << std::hex << json_cmp[idx]["uncomp"].asString().substr(2);
        ss >> data_cmp;
        data_cmp &= 0xffff;

        Json::Value val;
        val["comp"] = fmt::format("0x{:x}", p_top->i_instruction);
        val["uncomp_exp"] = json_cmp[idx]["uncomp"];
        val["uncomp"] = fmt::format("0x{:x}", p_top->o_instruction);
        val["invalid"] = p_top->o_illegal_instruction;
        json_res.append(val);

        uint32_t data = p_top->o_instruction & 0xffff;
        if (data_cmp != data)
        {
            std::cout << "Expected value: " << std::hex << data_cmp << std::dec << std::endl;
            std::cout << "Get value:      " << std::hex << data << std::dec << std::endl;
            return 1;
        }
    }
    return 0;
}

int main(int argc, char** argv, char** env)
{
    TB* tb = new TB(TOP_NAME_STR, argc, argv);
    tb->init(on_step_cb);
    TOP_CLASS* top = tb->get_top();
    int ret = 0;

    std::ifstream f_in;
    f_in.open("../" TOP_NAME_STR ".json", std::ios::out);
    Json::Reader reader;
    if (!reader.parse(f_in, json_cmp, false))
    {
        std::cout << "Unable to read valid result from file!" << std::endl;
        return -1;
    }
    f_in.close();

    auto start = std::chrono::system_clock::now();
    uint32_t i;
    for (i=0 ; i<0x10000 ; ++i)
    {
        top->i_instruction = (0x5aff0000 | i);
        if (tb->run_steps(2)  > 0)
        {
            ret = 1;
            break;
        }
    }
    auto end = std::chrono::system_clock::now();
    std::chrono::duration<double> elapsed_seconds = end-start;

    std::ofstream f_out;
    f_out.open("./" TOP_NAME_STR ".json", std::ios::out);
    Json::StyledStreamWriter writer("\t");
    writer.write(f_out, json_res);
    f_out.close();

    std::cout << std::setprecision(3) << "Simulation time: " << elapsed_seconds.count() <<
        " Iterations: " << i << std::endl;
    std::cout << "Simulation result: " << ((ret == 0) ? "PASS" : "FAIL") << std::endl;

    tb->finish();
    top->final();
#if VM_COVERAGE
    //tb->get_context()->coveragep()->write(COV_FN);
#endif
    return ret;
}
