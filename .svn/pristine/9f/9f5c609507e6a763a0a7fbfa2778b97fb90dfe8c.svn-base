// Author:        Ricardas Stoma
// Company:       Kolmisoft
// Year:          2014
// About:         Script merges several tariffs into one

// DEFINITIONS

#define SCRIPT_PATH           "/usr/local/mor/m2_tariff_generator"
#define LOG_FILE              "/var/log/mor/m2_tariff_generator.log"
#define TMP_TABLE_NAME        "tmp_tarrif_generator_table"
#define RATES_CSV_FILE        "/var/m2/tariff_generator/rates.scv"
#define RATEDETAILS_CSV_FILE  "/var/m2/tariff_generator/ratedetails.scv"


// TO-DO:
//
//      * use limits to get tariffs in smaller portions (maybe no need to? will we ever have more than 1M rates in one tariff? probably not... even then, is it too big?)


// INCLUDES

#include "/usr/src/mor/scripts/m2_functions.c"

// GLOBAL VARIABLES

char tariff_name[256] = "";
char currency[256] = "";
char currency_name[256] = "";
char profit_margin[256] = "";
double profit_margin_decimal = 0;
char tariff_list[1024] = "";
double exchange_rate = 1;
int tariff_id = 0;
char tmp_table_uid[64] = "";

typedef struct rates_struct {
    unsigned int destination_id;
    double rate;
    unsigned long int rate_id;
} rates_t;

rates_t *rates = NULL;
unsigned long int rates_count = 0;

// FUNCTION DECLARATIONS

int get_exchange_rate(char *currency);
int get_new_tariff_table();
int export_rates_to_csv();
int export_ratedetails_to_csv();
int create_new_tariff(char *tariff_name);
int insert_rates();
int insert_ratedetails();
int get_rates_id();

// MAIN FUNCTION

int main(int argc, char *argv[]) {

    m2_init("Starting M2 tariff generator\n");

    m2_task_get(3, NULL, tariff_name, currency, profit_margin, tariff_list, NULL, NULL);

    m2_task_lock();

    system("mkdir -p /var/m2/tariff_generator");
    system("rm -fr /var/m2/tariff_generator/*");

    // get exchange rate
    if (get_exchange_rate(currency)) {
        m2_log("Exchange rate for currency %s not foud\n", currency);
        m2_task_unlock(4);
        return 1;
    }

    // merge tariffs
    if (get_new_tariff_table()) {
        m2_log("Tariff table could not be generated\n");
        m2_task_unlock(4);
        return 1;
    }

    if (rates_count > 0) {

        if (create_new_tariff(tariff_name)) {
            m2_log("New tariff '%s' was not created\n", tariff_name);
            return 1;
        }

        if (export_rates_to_csv()) {
            m2_log("Rates CSV import failed\n");
            return 1;
        }

        if (insert_rates()) {
            m2_log("Failed to insert new rates\n");
            return 1;
        }

        if (get_rates_id()) {
            m2_log("Failed to get rates id\n");
            return 1;
        }

        if (export_ratedetails_to_csv()) {
            m2_log("Ratedetails CSV import failed\n");
            return 1;
        }

        if (insert_ratedetails()) {
            m2_log("Failed to insert new ratedetails\n");
            return 1;
        }

    } else {
        m2_log("Rates not found\n");
    }

    m2_task_finish();

    // close mysql connection
    mysql_close(&mysql);
    mysql_library_end();
    if (rates) {
        free(rates);
        rates = NULL;
    }

    m2_log("Task completed\n");

    return 0;

}


/*

    ############  FUNCTIONS #######################################################

*/


/*
    Merge tariffs into one tariff and apply profit margin
*/


int get_new_tariff_table() {

    m2_log("Reading tariffs\n");

    MYSQL_RES *result;
    MYSQL_ROW row;

    char query[4096] = "";

    profit_margin_decimal = atof(profit_margin);

    sprintf(query, "SELECT destinations.id, (MIN(ratedetails.rate / currencies.exchange_rate) * (1 + %f/100)) * %f AS 'rate' FROM rates "
                   "INNER JOIN tariffs ON (tariffs.id = rates.tariff_id AND tariffs.id IN (%s)) "
                   "INNER JOIN currencies ON currencies.name = tariffs.currency "
                   "INNER JOIN destinations ON rates.destination_id = destinations.id "
                   "LEFT JOIN ratedetails ON ratedetails.rate_id = rates.id "
                   "GROUP BY destinations.id ORDER BY destinations.id ASC", profit_margin_decimal, exchange_rate, tariff_list);

    if (m2_mysql_query(query)) {
        return 1;
    }

    result = mysql_store_result(&mysql);
    if (result) {
        if (mysql_num_rows(result)) {
            while (( row = mysql_fetch_row(result) )) {

                rates = realloc(rates, (rates_count + 1) * sizeof(rates_t));

                if (rates == NULL) {
                    m2_log("Memory reallocation error (number of rates: %lu)\n", rates_count);
                    m2_task_unlock(4);
                    exit(1);
                }

                if (row[0]) rates[rates_count].destination_id = atoi(row[0]);
                if (row[1]) rates[rates_count].rate = atof(row[1]);
                rates[rates_count].rate_id = 0;

                rates_count++;

            }
        }
    }

    mysql_free_result(result);

    return 0;

}


/*
    Get exchange rate for specific currency
*/


int get_exchange_rate(char *currency) {

    m2_log("Reading exchange rate for currency: %s\n", currency);

    MYSQL_RES *result;
    MYSQL_ROW row;

    char query[4096] = "";

    sprintf(query, "SELECT exchange_rate, name FROM currencies WHERE id = %s LIMIT 1", currency);

    if (m2_mysql_query(query)) {
        return 1;
    }

    result = mysql_store_result(&mysql);
    if (result) {
        row = mysql_fetch_row(result);
        if (row) {
            if (row[0]) exchange_rate = atof(row[0]);
            if (row[1]) strcpy(currency_name, row[1]);
        }
    }

    mysql_free_result(result);

    m2_log("Currency name: %s, exchange_rate: %0.5f\n", currency_name, exchange_rate);

    return 0;

}


/*
    Insert rates to database
*/


int insert_rates() {

    m2_log("Inserting rates into database\n");

    char query[4096] = "";

    sprintf(query, "LOAD DATA LOCAL INFILE '" RATES_CSV_FILE "' INTO TABLE rates FIELDS TERMINATED BY ';' LINES TERMINATED BY '\\n' (destination_id, tariff_id)");

    if (m2_mysql_query(query)) {
        return 1;
    }

    m2_log("Insert completed\n");

    return 0;

}


/*
    Export rates to CSV file
*/


int export_rates_to_csv() {

    m2_log("Importing rates to CSV file " RATES_CSV_FILE "\n");

    unsigned long int i = 0;
    FILE *fp = fopen(RATES_CSV_FILE, "w");

    if (fp == NULL) {
        m2_log("Cannot open " RATES_CSV_FILE "\n");
        return 1;
    }

    for (i = 0; i < rates_count; i++) {
        fprintf(fp, "%u;%d\n", rates[i].destination_id, tariff_id);
    }

    fclose(fp);

    m2_log("Import completed\n");

    return 0;

}


/*
    Export ratedetails to CSV file
*/


int export_ratedetails_to_csv() {

    m2_log("Importing rates to CSV file " RATEDETAILS_CSV_FILE "\n");

    unsigned long int i = 0;
    FILE *fp = fopen(RATEDETAILS_CSV_FILE, "w");

    if (fp == NULL) {
        m2_log("Cannot open " RATEDETAILS_CSV_FILE "\n");
        return 1;
    }

    for (i = 0; i < rates_count; i++) {
        fprintf(fp, "%lu;%0.6f\n", rates[i].rate_id, rates[i].rate);
    }

    fclose(fp);

    m2_log("Import completed\n");

    return 0;

}


/*
    Create new tariff with given name and check if tariff already exists with this name
*/


int create_new_tariff(char *tariff_name) {

    m2_log("Checking if tariff '%s' already exists\n", tariff_name);

    MYSQL_RES *result1;
    MYSQL_RES *result2;
    MYSQL_ROW row;

    char query[4096] = "";

    sprintf(query, "SELECT id FROM tariffs WHERE name = '%s' LIMIT 1", tariff_name);

    if (m2_mysql_query(query)) {
        return 1;
    }

    result1 = mysql_store_result(&mysql);
    if (result1) {
        row = mysql_fetch_row(result1);
        if (row) {
            if (row[0]) tariff_id = atoi(row[0]);
        }
    }

    mysql_free_result(result1);

    if (tariff_id) {

        m2_log("Tariff '%s' already exists! Another tariff with the same name will not be created\n", tariff_name);
        m2_task_unlock(4);
        exit(1);

    } else {

        m2_log("Tariff '%s' does not exists. New tariff will be created\n", tariff_name);

        sprintf(query, "INSERT INTO tariffs (name, purpose, currency) VALUES ('%s', 'user_wholesale', '%s')", tariff_name, currency_name);

        if (m2_mysql_query(query)) {
            return 1;
        }

        sprintf(query, "SELECT id FROM tariffs WHERE name = '%s' LIMIT 1", tariff_name);

        if (m2_mysql_query(query)) {
            return 1;
        }

        result2 = mysql_store_result(&mysql);
        if (result2) {
            row = mysql_fetch_row(result2);
            if (row) {
                if (row[0]) tariff_id = atoi(row[0]);
            }
        }

        mysql_free_result(result2);

        if (!tariff_id) {
            return 1;
        }

    }

    m2_log("New tariff '%s' was successfully created! Tariff id: %d\n", tariff_name, tariff_id);

    return 0;

}


/*
    Get rates id for ratedetails mapping (because we will be sorting by destinations, then mapping between ratedetails and rates should be direct)
*/


int get_rates_id() {

    m2_log("Reading rates id from database\n");

    MYSQL_RES *result;
    MYSQL_ROW row;
    unsigned long int count = 0;

    char query[4096] = "";

    sprintf(query, "SELECT id FROM rates WHERE tariff_id = %d ORDER BY rates.destination_id", tariff_id);

    if (m2_mysql_query(query)) {
        return 1;
    }

    result = mysql_store_result(&mysql);

    if (result) {
        while (( row = mysql_fetch_row(result) )) {
            if (row[0]) {
                if (count < rates_count) {
                    rates[count].rate_id = atol(row[0]);
                }
                count++;
            }
        }
    }

    if (count != rates_count) {
        m2_log("Something went wrong when reading rate id. Rate count: %lu, count: %lu\n", rates_count, count);
        mysql_free_result(result);
        return 1;
    } else {
        m2_log("Reading comleted\n");
    }

    mysql_free_result(result);

    return 0;

}


/*
    Get rates id for ratedetails mapping (because we will be sorting by destinations, then mapping between ratedetails and rates should be direct)
*/


int insert_ratedetails() {

    m2_log("Inserting ratedetails into database\n");

    char query[4096] = "";

    sprintf(query, "LOAD DATA LOCAL INFILE '" RATEDETAILS_CSV_FILE "' INTO TABLE ratedetails FIELDS TERMINATED BY ';' LINES TERMINATED BY '\\n' (rate_id, rate)");

    if (m2_mysql_query(query)) {
        return 1;
    }

    m2_log("Insert completed\n");

    return 0;

}
