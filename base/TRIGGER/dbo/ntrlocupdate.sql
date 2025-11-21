SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Trigger: ntrLocUpdate                                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 17-Oct-2003  YokeBeen      NIKE Regional (NSC) Project (SOS#15352)   */
/*                            - (YokeBeen01)                            */
/* 28-Dec-2004  YokeBeen      For NSC 947-InvAdj - (YokeBeen02)         */
/* 08-Aug-2006  Vicky         Generic Configkey (INVHOLDLOG) for        */
/*                            Inventory Hold Interface                  */
/* 23-Apr-2007	Vicky         SOS#74049 - Fix interface double sending  */
/* 04-May-2007  Vicky         SOS#74919 - Insert direct to Transmitlog3 */
/*                            without checking on uniqueness of         */
/*                            Key1 + Key2  + Key3 for INVHOLDLOG        */
/* 04-Jul-2007  Vicky         SOS#80373 - Add checking on duplicate     */
/*                            Invholdkey with both status = 0 being     */
/*                            inserted into Transmitlog3                */
/* 01-Oct-2009  Shong         Only Update LOC.Cube if L/W/H was updated */
/* 26-Jun-2010  Shong         SOS#179299 Default LOCCheckDigit          */
/* 02-May-2012  Shong         Do Not Allow Update LOC Type DynPickP &   */
/*                            DynPickR to LoseID                        */
/* 25 May2012   TLTING01      DM integrity - add update editdate B4     */
/*                            TrafficCop                                */
/* 06-Sep-2012  KHLim         Move up ArchiveCop (KH01)                 */
/* 09-APR-2013  Shong         Change LocCheckDigit to 2 Numeric Digit   */
/*                            for Voice Implementation                  */
/* 03-May-2013  Ung           Add DPLOCNotAllowLoseID                   */
/* 28-Oct-2013  TLTING        Review Editdate column update             */
/* 08-Nov-2016  SHONG002      Not allow to change location type if qty  */
/*                            over-allocated                            */
/* 16-Jan-2019  TLTING02      missing nolock                            */
/* 21-Dec-2022  NJOW01        WMS-21370 add config to prevent update    */
/*                            facility with stock                       */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrLocUpdate]
    ON [dbo].[LOC]
    FOR UPDATE
    AS
BEGIN
    IF @@ROWCOUNT = 0
        BEGIN
            RETURN
        END
    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
    -- SET CONCAT_NULL_YIELDS_NULL OFF

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
        , @c_FoundLoc NVARCHAR(10) --NJOW01

    SELECT @b_Success = 0
         , @n_err = 0
         , @n_err2 = 0
         , @c_errmsg = ''
         , @n_continue = 0
         , @n_starttcnt = 0
         , @c_preprocess = ''
         , @c_pstprocess = ''
         , @n_cnt = 0

    SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT
    IF UPDATE(ArchiveCop) --KH01
        BEGIN
            SELECT @n_continue = 4
        END

    IF (@n_continue = 1 OR @n_continue = 2) AND NOT UPDATE(EditDate)
        BEGIN
            UPDATE LOC with (ROWLOCK)
            SET EditWho    = sUser_sName(),
                EditDate   = GetDate(),
                TrafficCop = NULL
            FROM LOC
                     JOIN INSERTED ON LOC.LOC = INSERTED.LOC
            IF @@ERROR <> 0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @n_err = @@ERROR
                    SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err) +
                                       ': Update Error on Table LOC (ntrLocUpdate)'
                END
        END


    IF UPDATE(TrafficCop)
        BEGIN
            SELECT @n_continue = 4
        END

    /* #INCLUDE <TRLU1.SQL> */
    /*--------------->>>>> Start FBRC08 <<<<<---------------*/
    /* Author: Wally M.					*/
    /* Date: 03.14.00					*/
    /* Purpose: calculate dimension and default to cube	*/
    /*------------------------------------------------------*/
    IF @n_continue = 1 or @n_continue = 2
        BEGIN
            IF UPDATE(Length) OR UPDATE(Width) OR UPDATE(Height)
                UPDATE LOC
                SET LOC.cube   = (INSERTED.length * INSERTED.width * INSERTED.height),
                    trafficcop = NULL,
                    EditDate   = GETDATE(),
                    EditWho    = SUSER_SNAME()
                FROM LOC,
                     INSERTED
                WHERE LOC.loc = INSERTED.loc
            IF @@ERROR <> 0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @n_err = @@ERROR
                    SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err) +
                                       ': Update Error on Table LOC (ntrLocUpdate)'
                END
        END
    /*--------------->>>>> End FBRC08 <<<<<---------------*/

    IF @n_continue = 1 or @n_continue = 2
        BEGIN
            IF EXISTS(SELECT 1
                      FROM INSERTED
                      WHERE LocationType IN ('DYNPICKP', 'DYNPICKR') AND LoseID = '1') AND
               EXISTS(SELECT 1
                      FROM StorerConfig WITH (NOLOCK)
                               JOIN INSERTED ON (INSERTED.Facility = StorerConfig.Facility)
                      WHERE StorerConfig.ConfigKey = 'DPLOCNotAllowLoseID'
                        AND SValue = '1')
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @n_err = 78502
                    SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) +
                                       ': Dynamic Pick Location Not Allow Lose ID (ntrLocUpdate)'
                END
        END

    IF @n_continue = 1 or @n_continue = 2
        BEGIN
            IF EXISTS(SELECT 1 FROM INSERTED WHERE LocationType IN ('DYNPPICK') AND LoseID = '0')
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @n_err = 78504
                    SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) +
                                       ': Dynamic Permanent Pick Location Must Lose ID (ntrLocUpdate)'
                END
        END
    -- SHONG002
    IF UPDATE(LocationType)
        BEGIN
            IF EXISTS (SELECT INSERTED.LOC
                       FROM INSERTED
                                JOIN DELETED ON INSERTED.LOC = DELETED.LOC
                       WHERE DELETED.LocationType IN ('DYNPPICK', 'DYNPICKP', 'DYNPICKR')
                         AND INSERTED.LocationType NOT IN ("DYNPPICK", 'DYNPICKP', 'DYNPICKR')
                         AND EXISTS(SELECT 1
                                    FROM SKUxLOC AS SL WITH (NOLOCK)
                                    WHERE SL.Loc = INSERTED.LOC
                                      AND (SL.Qty - (SL.QtyAllocated + SL.QtyPicked)) < 0))
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @n_err = 78505
                    SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) +
                                       ': Found Over-Allocated Inventory, Not Allow to Change Location Type (ntrLocUpdate)'
                END
        END

    IF @n_continue = 1 or @n_continue = 2
        BEGIN
            IF UPDATE(LOCATIONFLAG)
                BEGIN
                    IF EXISTS(SELECT 1
                              FROM DELETED,
                                   INSERTED,
                                   LOTxLOCxID (NOLOCK) --tlting02
                              WHERE DELETED.LOC = INSERTED.LOC
                                AND LOTxLOCxID.LOC = INSERTED.LOC
                                AND LOTxLOCxID.LOC = DELETED.LOC
                                AND (DELETED.LOCATIONFLAG = 'DAMAGE' or
                                     DELETED.LOCATIONFLAG = 'HOLD')
                                AND INSERTED.LOCATIONFLAG <> 'DAMAGE'
                                AND INSERTED.LOCATIONFLAG <> 'HOLD'
                                AND LOTxLOCxID.QTY > 0)
                        BEGIN
                            SELECT @n_continue = 3
                            SELECT @n_err = 78501
                            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err) +
                                               ': Cannot Change LocationFlag From HOLD/DAMAGE if QTY > 0 . (ntrLocUpdate)'
                        END

                    IF @n_continue = 1 or @n_continue = 2
                        BEGIN
                            IF EXISTS(SELECT *
                                      FROM DELETED,
                                           INSERTED,
                                           LOTxLOCxID (NOLOCK) -- tlting02
                                      WHERE DELETED.LOC = INSERTED.LOC
                                        AND LOTxLOCxID.LOC = INSERTED.LOC
                                        AND LOTxLOCxID.LOC = DELETED.LOC
                                        AND (DELETED.LOCATIONFLAG <> 'DAMAGE' and
                                             DELETED.LOCATIONFLAG <> 'HOLD')
                                        AND (INSERTED.LOCATIONFLAG = 'DAMAGE' or
                                             INSERTED.LOCATIONFLAG = 'HOLD')
                                        AND LOTxLOCxID.QTY > 0)
                                BEGIN
                                    SELECT @n_continue = 3
                                    SELECT @n_err = 78503
                                    SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err) +
                                                       ': Cannot Change LocationFlag To HOLD/DAMAGE if QTY > 0 . (ntrLocUpdate)'
                                END
                        END
                END
        END

    --NJOW01 S
    IF @n_continue = 1 or @n_continue = 2
        BEGIN
            IF UPDATE(Facility)
                BEGIN
                    SELECT TOP 1 @c_FoundLoc = I.Loc
                    FROM INSERTED I
                             JOIN DELETED D ON I.LOC = D.LOC
                             JOIN LOTXLOCXID LLI (NOLOCK) ON I.Loc = LLI.Loc
                             CROSS APPLY (SELECT Storerkey, Configkey, Authority
                                          FROM dbo.fnc_GetRight2(D.Facility, LLI.storerkey, '',
                                                                 'NoUpdLocFacWithInv')
                                          WHERE Authority = '1') AS SC
                    WHERE I.Facility <> D.Facility
                      AND LLI.Qty + LLI.PendingMoveIn + LLI.QtyExpected > 0
                    ORDER BY I.Loc

                    IF ISNULL(@c_FoundLoc, '') <> ''
                        BEGIN
                            SELECT @n_continue = 3
                            SELECT @n_err = 78504
                            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err) +
                                               ': Cannot Change Facility of Loc ''' +
                                               RTRIM(@c_FoundLoc) +
                                               ''' With Stock On Hand or Pending move In. (ntrLocUpdate)'
                        END
                END
        END
    --NJOW02 E

-- (YokeBeen01) - Start
    IF @n_continue = 1 OR @n_continue = 2
        BEGIN
            DECLARE @c_Loc NVARCHAR(10)
                , @c_StorerKey NVARCHAR(15)
                , @c_Sku NVARCHAR(20)
                , @c_InsLocFlag NVARCHAR(10)
                , @c_DelLocFlag NVARCHAR(10)
                , @c_InsStatus NVARCHAR(10)
                , @c_DelStatus NVARCHAR(10)
                , @c_InsFlag NVARCHAR(1)
                , @c_DelFlag NVARCHAR(1)
                , @c_NIKEREGITF NVARCHAR(1)
                , @c_Invholditf NVARCHAR(1)
                , @c_InvHoldKey NVARCHAR(10)

            DECLARE @c_transmitlogkey NVARCHAR(10)

            -- SOS#74049 (Start)
            DECLARE @n_IDCnt int,
                @n_LotCnt int

            SELECT @n_IDCnt = 0,
                   @n_LotCnt = 0
            -- SOS#74049 (End)

            SELECT @c_Loc = ''
                 , @c_StorerKey = ''
                 , @c_Sku = ''
                 , @c_InsLocFlag = ''
                 , @c_DelLocFlag = ''
                 , @c_InsStatus = ''
                 , @c_DelStatus = ''
                 , @c_InsFlag = ''
                 , @c_DelFlag = ''
                 , @c_NIKEREGITF = ''
                 , @c_Invholditf = '0'

            IF EXISTS (SELECT INVENTORYHOLD.LOC
                       FROM INVENTORYHOLD (NOLOCK),
                            INSERTED,
                            DELETED
                       WHERE INSERTED.LOC = DELETED.LOC
                         AND INSERTED.LOC = INVENTORYHOLD.LOC
                         AND INSERTED.STATUS <> DELETED.STATUS)
                BEGIN
                    SELECT @c_Storerkey = SKUxLOC.Storerkey
                    FROM SKUxLOC (NOLOCK),
                         INSERTED (NOLOCK)
                    WHERE SKUxLOC.Loc = INSERTED.Loc

                    SELECT @b_success = 0
                    SELECT @c_NIKEREGITF = '0'

                    EXECUTE nspGetRight
                            NULL, -- facility
                            @c_storerkey, -- Storerkey
                            NULL, -- Sku
                            'NIKEREGITF', -- Configkey
                            @b_success OUTPUT,
                            @c_NIKEREGITF OUTPUT,
                            @n_err OUTPUT,
                            @c_errmsg OUTPUT

                    IF @b_success <> 1
                        BEGIN
                            SELECT @n_continue = 3
                            SELECT @c_errmsg = 'ntrLocUpdate' + dbo.fnc_RTrim(@c_errmsg)
                        END
                    ELSE
                        IF @c_NIKEREGITF = '1'
                            BEGIN
                                SELECT @c_Loc = INSERTED.Loc,
                                       @c_InsFlag = CASE
                                                        WHEN ((INSERTED.Locationflag = 'HOLD') OR
                                                              (INSERTED.Locationflag = 'DAMAGE')
                                                            OR (INSERTED.Status = 'HOLD'))
                                                            THEN '1'
                                                        ELSE '0' END,
                                       @c_DelFlag = CASE
                                                        WHEN ((DELETED.Locationflag = 'HOLD') OR
                                                              (DELETED.Locationflag = 'DAMAGE')
                                                            OR (DELETED.Status = 'HOLD'))
                                                            THEN '1'
                                                        ELSE '0' END
                                FROM DELETED (NOLOCK)
                                         JOIN INSERTED (NOLOCK) ON (DELETED.Loc = INSERTED.Loc)
                                GROUP BY INSERTED.Loc,
                                         CASE
                                             WHEN ((INSERTED.Locationflag = 'HOLD') OR
                                                   (INSERTED.Locationflag = 'DAMAGE')
                                                 OR (INSERTED.Status = 'HOLD'))
                                                 THEN '1'
                                             ELSE '0' END,
                                         CASE
                                             WHEN ((DELETED.Locationflag = 'HOLD') OR
                                                   (DELETED.Locationflag = 'DAMAGE')
                                                 OR (DELETED.Status = 'HOLD'))
                                                 THEN '1'
                                             ELSE '0' END

                                -- (YokeBeen02) - Start
                                -- When Hold or UnHold
                                IF ((@c_InsFlag = 1) AND (@c_DelFlag = 0)) OR
                                   ((@c_InsFlag = 0) AND (@c_DelFlag = 1))
                                    BEGIN
                                        BEGIN TRAN
                                            INSERT INTO INVHOLDTRANSLOG
                                                (Sku, StorerKey, Facility, SourceKey, SourceType, UserID)
                                                (SELECT DISTINCT SKUxLOC.Sku,
                                                                 @c_StorerKey,
                                                                 INSERTED.Facility,
                                                                 SKUxLOC.Loc,
                                                                 'LOC',
                                                                 SUSER_SNAME()
                                                 FROM INSERTED (NOLOCK)
                                                          JOIN SKUxLOC (NOLOCK) ON (INSERTED.Loc = SKUxLOC.Loc)
                                                 WHERE dbo.fnc_RTrim(SKUxLOC.Loc) = dbo.fnc_RTrim(@c_Loc)
                                                   AND SKUxLOC.Storerkey = @c_StorerKey
                                                 GROUP BY SKUxLOC.Sku, INSERTED.Facility, SKUxLOC.Loc)
                                        COMMIT TRAN
                                        -- (YokeBeen02) - End
                                    END -- when Hold or UnHold
                            END
                    -- IF @c_NIKEREGITF = '1'

                    -- Generic Configkey (Start)
                    SELECT @b_success = 0
                    EXECUTE nspGetRight
                            NULL, -- facility
                            @c_storerkey, -- Storerkey
                            NULL, -- Sku
                            'INVHOLDLOG', -- Configkey
                            @b_success OUTPUT,
                            @c_Invholditf OUTPUT,
                            @n_err OUTPUT,
                            @c_errmsg OUTPUT

                    IF @b_success <> 1
                        BEGIN
                            SELECT @n_continue = 3
                            SELECT @c_errmsg = 'ntrLocUpdate' + dbo.fnc_RTrim(@c_errmsg)
                        END
                    ELSE
                        IF @c_Invholditf = '1'
                            BEGIN
                                SELECT @c_Loc = INSERTED.Loc,
                                       @c_InsFlag = CASE
                                                        WHEN ((INSERTED.Locationflag = 'HOLD') OR
                                                              (INSERTED.Status = 'HOLD'))
                                                            THEN '1'
                                                        ELSE '0' END,
                                       @c_DelFlag = CASE
                                                        WHEN ((DELETED.Locationflag = 'HOLD') OR
                                                              (DELETED.Status = 'HOLD'))
                                                            THEN '1'
                                                        ELSE '0' END
                                FROM DELETED (NOLOCK)
                                         JOIN INSERTED (NOLOCK) ON (DELETED.Loc = INSERTED.Loc)
                                GROUP BY INSERTED.Loc,
                                         CASE
                                             WHEN ((INSERTED.Locationflag = 'HOLD') OR
                                                   (INSERTED.Status = 'HOLD'))
                                                 THEN '1'
                                             ELSE '0' END,
                                         CASE
                                             WHEN ((DELETED.Locationflag = 'HOLD') OR
                                                   (DELETED.Status = 'HOLD'))
                                                 THEN '1'
                                             ELSE '0' END

                                SELECT @c_InvHoldKey = INVENTORYHOLD.InventoryHoldKey
                                FROM INVENTORYHOLD (NOLOCK),
                                     INSERTED
                                WHERE INSERTED.LOC = INVENTORYHOLD.LOC
                                  AND INSERTED.LOC = @c_Loc

                                -- When Hold or UnHold
                                IF ((@c_InsFlag = 1) AND (@c_DelFlag = 0)) OR
                                   ((@c_InsFlag = 0) AND (@c_DelFlag = 1))
                                    BEGIN
                                        BEGIN TRAN
                                            IF @c_InsFlag = 1
                                                BEGIN
                                                    SELECT @c_InsLocFlag = 'HOLD'
                                                END
                                            ELSE
                                                IF @c_InsFlag = 0
                                                    BEGIN
                                                        SELECT @c_InsLocFlag = 'OK'
                                                    END
                                            -- SOS#74049 - To fix double sending of records (Start)
                                            SELECT @n_IDCnt = 0, @n_LotCnt = 0

                                            SELECT @n_IDCnt = COUNT(*)
                                            FROM TRANSMITLOG3 T3 (NOLOCK)
                                                     JOIN INVENTORYHOLD IH (NOLOCK)
                                                          ON (IH.InventoryHoldKey = T3.Key1)
                                                     JOIN LOTxLOCxID LLI (NOLOCK)
                                                          ON (LLI.ID = IH.ID AND
                                                              LLI.Storerkey = @c_StorerKey AND
                                                              LLI.LOC = @c_Loc)
                                            WHERE T3.Tablename = 'INVHOLDLOG-ID'
                                              AND T3.Transmitflag = '0'
                                              AND T3.Key2 = @c_InsLocFlag

                                            IF @n_IDCnt = 0
                                                BEGIN
                                                    SELECT @n_LotCnt = COUNT(*)
                                                    FROM TRANSMITLOG3 T3 (NOLOCK)
                                                             JOIN INVENTORYHOLD IH (NOLOCK)
                                                                  ON (IH.InventoryHoldKey = T3.Key1)
                                                             JOIN LOTxLOCxID LLI (NOLOCK)
                                                                  ON (LLI.LOT = IH.LOT AND
                                                                      LLI.Storerkey =
                                                                      @c_StorerKey AND
                                                                      LLI.LOC = @c_Loc)
                                                    WHERE T3.Tablename = 'INVHOLDLOG-LOT'
                                                      AND T3.Transmitflag = '0'
                                                      AND T3.Key2 = @c_InsLocFlag
                                                END

                                            IF (@n_IDCnt = 0) AND (@n_LotCnt = 0)
                                                BEGIN
                                                    --                Commented By Vicky for SOS#74919 (Start)
-- 	               SELECT @b_success = 1
-- 			         EXEC ispGenTransmitLog3 'INVHOLDLOG-LOC', @c_InvHoldKey, @c_InsLocFlag, @c_Storerkey, ''
-- 			         , @b_success OUTPUT
-- 			         , @n_err OUTPUT
-- 			         , @c_errmsg OUTPUT
--
-- 	               IF @b_success <> 1
-- 			         BEGIN
-- 			            SELECT @n_continue = 3
-- 			            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
-- 			            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrLocUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
-- 			         END
--                Commented By Vicky for SOS#74919 (End)
                                                    -- SOS#80373 (Start)
                                                    IF NOT EXISTS (SELECT 1
                                                                   FROM TransmitLog3 (NOLOCK)
                                                                   WHERE TableName = 'INVHOLDLOG-LOC'
                                                                     AND Key1 = @c_InvHoldKey
                                                                     AND Key2 = @c_InsLocFlag
                                                                     AND Key3 = @c_Storerkey
                                                                     AND Transmitflag = '0')
                                                        BEGIN
                                                            --                Added By Vicky for SOS#74919 (Start)
                                                            SELECT @c_transmitlogkey = ''
                                                            SELECT @b_success = 1
                                                            EXECUTE nspg_getkey
                                                                    'TransmitlogKey3'
                                                                , 10
                                                                , @c_transmitlogkey OUTPUT
                                                                , @b_success OUTPUT
                                                                , @n_err OUTPUT
                                                                , @c_errmsg OUTPUT

                                                            IF @b_success <> 1
                                                                BEGIN
                                                                    SELECT @n_continue = 3
                                                                END
                                                            ELSE
                                                                BEGIN
                                                                    INSERT INTO TRANSMITLOG3 (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                                                                    VALUES (@c_transmitlogkey,
                                                                            'INVHOLDLOG-LOC',
                                                                            @c_InvHoldKey,
                                                                            @c_InsLocFlag,
                                                                            @c_Storerkey, '0')

                                                                    SELECT @n_err = @@Error

                                                                    IF NOT @n_err = 0
                                                                        BEGIN
                                                                            SELECT @n_continue = 3
                                                                            Select @c_errmsg = CONVERT(char(250), @n_err),
                                                                                   @n_err = 74562
                                                                            Select @c_errmsg =
                                                                                   'NSQL' +
                                                                                   CONVERT(char(5), @n_err) +
                                                                                   ':Insert failed on TransmitLog3. (ntrLocUpdate)' +
                                                                                   '(' +
                                                                                   'SQLSvr MESSAGE=' +
                                                                                   dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) +
                                                                                   ')'
                                                                        END
                                                                END --  Added By Vicky for SOS#74919 (End)
                                                        END -- SOS#80373 (End)
                                                END
                                            -- SOS#74049 - To fix double sending of records (End)
                                        COMMIT TRAN
                                    END -- when Hold or UnHold
                            END
                    -- IF @c_Invholditf = '1'
                    -- Generic Configkey (End)
                END -- If Record Exists
        END
    -- IF @n_continue = 1 OR @n_continue = 2
-- (YokeBeen01) - End

-- SOS#179299 Default LocCheckDigit
    IF UPDATE(LOC)
        BEGIN
            UPDATE LOC
            SET --LocCheckDigit = dbo.fnc_GetLocCheckDigit(INSERTED.LOC),
                LOC.TrafficCop = NULL,
                EditDate       = GETDATE(),
                EditWho        = SUSER_SNAME()
            FROM LOC
                     JOIN INSERTED ON LOC.LOC = INSERTED.LOC

        END

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

            EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrLocUpdate'
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