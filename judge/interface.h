#ifndef INTERFACE_H
#define INTERFACE_H
/*
    TU JEST UCHWYT DO OCAML
*/


/*
  | 0 -> Domain.Accepted
  | 1 -> Domain.Rejected
  | 2 -> Domain.Invalid_format
  | _ -> Domain.Internal_error
*/
extern "C" int judge_a_submission(char* task, char* submission);

#endif