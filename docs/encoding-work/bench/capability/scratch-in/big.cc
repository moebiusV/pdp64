#include <map>
#include <regex>
#include <string>
#include <vector>
#include <algorithm>
#include <iostream>
#include <unordered_map>
int main(){std::regex r("a+b");std::map<int,std::string> m;std::unordered_map<std::string,int> u;std::vector<int> v;for(int i=0;i<10;i++){m[i]=std::to_string(i);u[m[i]]=i;v.push_back(i);}std::sort(v.begin(),v.end());std::cout<<std::regex_match("aab",r);}
