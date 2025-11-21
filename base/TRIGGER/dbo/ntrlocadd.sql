SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrLocAdd                                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/* Version: 5.5                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 26-Jun-2010  Shong         Default LocCheckDigit When Loc Added      */
/*                            SOS#179299                                */
/* 11-Mar-2013  TKLim         Fix bug that cause @n_continue = 4 and    */
/*                            skip the LocCheckDigit generation (TK01)  */
/* 09-APR-2013  Shong         Change LocCheckDigit to 2 Numeric Digit   */
/*                            for Voice Implementation                  */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrLocAdd]
    ON [dbo].[LOC]
    FOR INSERT
    AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE
        @b_Success int -- Populated by calls to stored procedures - was the proc successful?
        , @n_err int -- Error number returned by stored procedure or this trigger
        , @n_err2 int -- For Additional Error Detection
        , @c_errmsg NVARCHAR(250) -- Error message returned by stored procedure or this trigger
        , @n_continue int
        , @n_starttcnt int -- Holds the current transaction count
        , @c_preprocess NVARCHAR(250) -- preprocess
        , @c_pstprocess NVARCHAR(250) -- post process
        , @n_cnt int
    SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT

    --TK01 - S
    --Not suppose to check
    --IF UPDATE(TrafficCop)
    --BEGIN
    --   SELECT @n_continue = 4
    --END
    --TK01 - E

    IF EXISTS(SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
        BEGIN
            SELECT @n_continue = 4
        END
    /* #INCLUDE <TRLU1.SQL> */
    /*--------------->>>>> Checking For Putawayzone <<<<<------------------*/
    /* Author: Shong.                                                      */
    /* Date: 18-Dec-2003                                                   */
    /* Purpose: To Prevend user setup the Loc without PutawayZone exists,  */
    /*          this will cause the allocation fail.                       */
    /*---------------------------------------------------------------------*/
    IF NOT EXISTS(SELECT LOC
                  FROM INSERTED
                           JOIN PUTAWAYZONE (NOLOCK)
                                ON INSERTED.PutawayZone = PUTAWAYZONE.PutawayZone)
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250), @n_err),
                   @n_err = 74907 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err) +
                               ': PutawayZone NOT EXISTS in PutawayZone Table. (ntrLOCAdd)' +
                               ' ( ' + ' SQLSvr MESSAGE=' +
                               dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
        END
    IF EXISTS(SELECT LOC FROM INSERTED WHERE INSERTED.PutawayZone = '')
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250), @n_err),
                   @n_err = 74907 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err) +
                               ': PutawayZone Cannot be BLANK. (ntrLOCAdd)' + ' ( ' +
                               ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
        END
    /*--------------->>>>> Start FBRC08 <<<<<---------------*/
    /* Author: Wally M.             */
    /* Date: 03.14.00               */
    /* Purpose: calculate dimension and default to cube  */
    /*------------------------------------------------------*/
    IF @n_continue = 1 or @n_continue = 2
        BEGIN
            UPDATE LOC
            SET LOC.cube          = (INSERTED.length * INSERTED.width * INSERTED.height),
                -- Added by SHONG on 26-Jun-2010
                -- SOS#179299
                --LOC.LocCheckDigit = dbo.fnc_GetLocCheckDigit(INSERTED.LOC),
                trafficcop        = NULL
            FROM LOC,
                 INSERTED
            WHERE LOC.loc = INSERTED.loc
            IF @@ERROR <> 0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @n_err = @@ERROR
                    SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err) +
                                       ': Insert Error on Table LOC (ntrLocAdd)'
                END
        END
    /*--------------->>>>> End FBRC08 <<<<<---------------*/
    /* #INCLUDE <TRLU2.SQL> */
    IF @n_continue = 3 -- Error Occured - Process And Return
        BEGIN
            IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
                BEGIN
                    ROLLBACK TRAN
                END
            ELSE
                BEGIN
                    WHILE @@TRANCOUNT > @n_starttcnt
                        BEGIN
                            COMMIT TRAN
                        END
                END
            execute nsp_logerror @n_err, @c_errmsg, 'ntrLocAdd'
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
            RETURN
        END
    ELSE
        BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt
                BEGIN
                    COMMIT TRAN
                END
            RETURN
        END
END

GO