#!/bin/bash
# Arrays are following:
#  login(1) login(2) login(n..)
#  passw(1) passw(2) passw(n..)
Login_cp_array=(0312111111 0312222222)
# Passwords using complex characters must be quoted as in example
Password_cp_array=('Complexj$586@password' simplepassword_example)

Url="https://login.elcat.kg/cgi-bin/clients/"

function web_parser_worker() {
 Login_cp=$1
 Password_cp=$2 # if handtesting - must receive quoted text so complex passwords don't escape
 # Logging in and getting session ID
 DATA=$(curl -s --cookie-jar cookies.txt --data-raw "action=validate&language=ru&login=$Login_cp&password=$Password_cp" --url "$Url/login?language=ru")
 Session_id=$(echo $DATA | grep -P '(?<=session_id=)[a-z0-9]+' -o)

 # Accessing control panel and parsing payment data
 DATA=$(curl -s --cookie-jar cookies.txt --url "$Url/deal_account?session_id=$Session_id")
 # Cleaning-up page for processing, by default server responds with ebaniy WINDOWS-1251
 DATA=$(echo $DATA | iconv -f WINDOWS-1251 -t UTF8)

 # Parsing every field using advanced superbhuman Perl Regural Expressions
 Account_id=$(echo $DATA | grep -P '(?<=ДОГОВОР )[0-9]+' -o)
 Account_name=$(echo $DATA | grep -P '(?<=Наименование&nbsp;<\/td>\040<td>&nbsp;)\W*(?=<\/td)' -o)
 Account_balance=$(echo $DATA | grep -P '(?<=Сумма\040на\040счету&nbsp;<\/td>\040<td>&nbsp;)[0-9]*.[0-9]*' -o)
 Account_status=$(echo $DATA | grep -P '(?<=Статус&nbsp;</td>\040<td>&nbsp;)\W*(?=<\/td)' -o)
 local Account_service_login_array=($(echo $DATA | grep -P '[0-9]*(?=</a></td>\40<td\40class=)' -o))
 local Account_service_status_array=($(echo $DATA | grep -P '(?<=\">)[а-яА-Я]*(?=<\/td> <\/tr>)' -o))
 ##
 # Function map:	 $1			  $2			$3				$4						$5
 #echo -e "decision_maker received S1 $Account_balance S2 $Account_id S3 $Account_name S4 ${Account_service_login_array[@]} S5 ${#Account_service_status_array[*]}\n"
 decision_maker "$Account_balance" "$Account_id" "$Account_name" Account_service_login_array[@] Account_service_status_array[@]
}

function rocketchat_sender() {
 url='https://chat.domain.com/hooks/your_rocket_chat_hookURL_HERE'
 # Values received by this script:
 # Subject = $1 {ALERT.SUBJECT}
 # Message = $2 {ALERT.MESSAGE}
 subject="$1"
 # create message from subject and message
 message="${subject} $2"
 # build JSON message
 json="{\"text\":\"${message//\"/\\\"}\"}"
 # send it as a POST request to the Rocket.Chat incoming web-hook URL
 curl -X POST -H 'Content-Type: application/json' --data "$json" $url
}

function decision_maker() {
# emoji list
# dark :telephone_receiver:  
# yellow :mobile_phone_off: 
# red :no_mobile_phones:
##
# lowest $Account_balance value
account_warning_threshold=135
# message header to send
msg_header_template="Недостаток денежных средств на счету для оплаты следующего месяца!\t:mobile_phone_off:\n\n"
msg_body_template=""
msg_numbers_template="|||||||||||||||||||||||||||||||||||||\n"
msg_numbers_template_spacer=$msg_numbers_template
#remapping values and arrays
Account_decision_balance=$1
Account_decision_id=$2
Account_decision_name=$3
declare -a Account_decision_login_array=("${!4}")
declare -a Account_decision_status_array=("${!5}")
# echo -e "Account_decision_balance received as $1 and now it is $Account_decision_balance"
# echo -e "Account_decision_id received as $2 and now it is $Account_decision_id"
# echo -e "Account_decision_name received as $3 and now it is $Account_decision_name"
# echo -e "Account_decision_login_array received as $4 and now it is ${Account_decision_login_array[@]}"
# echo -e "Account_decision_status_array received as $5 and now it is ${Account_decision_status_array[@]}"


# ROUNDING balance because bash cant handle floatig numbers
printf -v Account_decision_balance_reporting %.2f "$Account_decision_balance"
printf -v Account_decision_balance %.0f "$Account_decision_balance"
# checking if balance is below threshold
if [[ $Account_decision_balance -lt $account_warning_threshold ]]
 then
  msg_body_template="Лицевой счет: $Account_decision_id $Account_decision_name\n"
  # looping trough all found phone numbers in account to build array of numbers and their statuses
  for ((loopopo=0; loopopo<${#Account_decision_login_array[*]}; loopopo++));
   do
    msg_numbers_template="$msg_numbers_template тел.:${Account_decision_login_array[loopopo]}\tсост.:${Account_decision_status_array[loopopo]}\n"
   done
  msg_numbers_template="$msg_numbers_template\nБаланс: $Account_decision_balance_reporting сом.:money_with_wings:\n$msg_numbers_template_spacer"
  msg_body_template="$msg_body_template $msg_numbers_template"
  echo "----------------------------"
  echo -e "\n***Sending message to rocket.chat for:***\n***$Account_decision_id $Account_decision_name***\n"
  echo -e "Message:\n$msg_header_template $msg_body_template"
  echo "----------------------------"
  rocketchat_sender "$msg_header_template" "$msg_body_template"
 else
  echo "----------------------------"
  echo -e "\nBALANCE IS OK\n Account:\n$Account_decision_id $Account_decision_name\nBalance: $Account_decision_balance сом."
  echo "----------------------------"
fi
}

# Loop runs trought all login-password pairs
for ((llelel=0; llelel<${#Login_cp_array[*]}; llelel++));
 do
  #echo -e "web_parser_worker received ${Login_cp_array[llelel]} ${Password_cp_array[llelel]}\n"
  web_parser_worker ${Login_cp_array[llelel]} ${Password_cp_array[llelel]}
done