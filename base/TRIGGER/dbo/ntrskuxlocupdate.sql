SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ntrSKUxLOCUpdate                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Trigger point upon any update on SKUxLOC                   */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 22-Jul-2004  SHONG     Convert SELECT MIN to Cursor Loop             */
/* 09-Nov-2005  SHONG     Not allow to update IF Over-Allocated qty     */
/*                        found in LOTxLOCxID (SHONG_20051109)          */
/* 22-Jul-2009  SHONG     SOS140686 - Dynamic Pick Location             */
/* 14-Sep-2010  SHONG     Include QtyAllocated for Priority Calculation */
/* 20-Dec-2010  SHONG     Performance Tuning                            */
/* 09-Sep-2011  TLTING01  New column update Editdate Edit Who           */
/*                        for Datamart Extraction                       */
/* 16-Apr-2012  Leong     SOS# 241110 - Bug fix for @n_PackCaseCnt      */
/* 25 May 2012  TLTING02  DM integrity - add update editdate B4         */
/*                        TrafficCop                                    */ 
/* 28-Oct-2013  TLTING    Review Editdate column update                 */
/* 15-Nov-2016  SHONG     Not allow to update location type to OTHER    */
/*                        even using trafficop in update                */
/* 28-Sep-2018  TLTING    Remove row lock                               */
/* 30-Mar-2021  NJOW01    WMS-16618 call custom stored proc             */ 
/************************************************************************/

CREATE TRIGGER [dbo].[ntrSKUxLOCUpdate]
ON  [dbo].[SKUxLOC]
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END -- @@ROWCOUNT = 0
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
     @b_Success    int       -- Populated by calls to stored procedures - was the proc successful?
   , @n_err        int       -- Error number returned by stored procedure OR this trigger
   , @n_err2       int       -- For Additional Error Detection
   , @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
   , @n_continue   int
   , @n_starttcnt  int       -- Holds the current transaction count
   , @c_preprocess NVARCHAR(250) -- preprocess
   , @c_pstprocess NVARCHAR(250) -- post process
   , @n_cnt        int
   , @c_Authority  NVARCHAR(1)

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END
   -- TLTING02
   IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
	   UPDATE SKUxLOC 
	   SET EditDate = GETDATE(),
	       EditWho = SUSER_SNAME(),
	       TrafficCop = NULL
	   FROM SKUxLOC (NOLOCK), INSERTED (NOLOCK)
	   WHERE SKUxLOC.StorerKey = INSERTED.StorerKey
	   AND SKUxLOC.SKU = INSERTED.SKU
	   AND SKUxLOC.LOC = INSERTED.LOC
	   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
	   IF @n_err <> 0
	   BEGIN
		   SELECT @n_continue = 3
		   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74565   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table SKUxLOC. (ntrSKUxLOCUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	   END
   END
     
   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END
    
   --NJOW01 S 
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey
                 JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE configkey = 'SKUXLOCTrigger_SP')
      BEGIN
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
          SELECT *
          INTO #INSERTED
          FROM INSERTED
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
   
          SELECT *
          INTO #DELETED
          FROM DELETED
   
         EXECUTE dbo.isp_SkuXLocTrigger_Wrapper
                   'UPDATE'  --@c_Action
                 , @b_Success  OUTPUT
                 , @n_Err      OUTPUT
                 , @c_ErrMsg   OUTPUT
   
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrSKUxLOCUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END
   
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END
   --NJOW01 E

    /* #INCLUDE <TRSLU1.SQL> */
   -- Added BY SHONG TO restrict user to change the location type from "CASE" OR "PICK" to Others
   -- IF this location is over allocated
   --IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF UPDATE(LocationType)
      BEGIN
         -- Check is any over allocated qty
         IF EXISTS ( SELECT INSERTED.LOC FROM DELETED, INSERTED
                     WHERE INSERTED.SKU = DELETED.SKU
                     AND   INSERTED.LOC = DELETED.LOC
                     AND   INSERTED.Storerkey = DELETED.Storerkey
                     AND   (INSERTED.Qty - ( INSERTED.QtyAllocated + INSERTED.QtyPicked )) < 0
                     AND   DELETED.LocationType IN ("CASE", "PICK")
                     AND   INSERTED.LocationType NOT IN ("CASE", "PICK")
                   )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err=74907   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Location Type Failed On Table SKUxLOC. Qty Over Allocated (ntrSKUxLOCUpdate)"
         END
         -- (SHONG_20051109) - don't run this IF 1st check was failed
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            -- Check is location lose id
            IF EXISTS ( SELECT INSERTED.LOC FROM DELETED, INSERTED, LOC (NOLOCK)
                        WHERE INSERTED.SKU = DELETED.SKU
                        AND   INSERTED.LOC = DELETED.LOC
                        AND   INSERTED.Storerkey = DELETED.Storerkey
                        AND   DELETED.LocationType NOT IN ("CASE", "PICK")
                        AND   INSERTED.LocationType IN ("CASE", "PICK")
                        AND   LOC.LOC = INSERTED.LOC
                        AND   LOC.LOC = DELETED.LOC
                        AND   LOC.LoseID = '0'
                        )
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74907   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Location Type Failed On Table SKUxLOC. Please Set Location to Lose Id (ntrSKUxLOCUpdate)"
            END
         END
         -- (SHONG_20051109) Start
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            -- Modified by SHONG on 09-Nov-2005
            -- Check the LOTxLOCxID OverAllocated Qty
            IF EXISTS ( SELECT INSERTED.LOC
                        FROM DELETED
                        JOIN INSERTED ON INSERTED.Storerkey = DELETED.Storerkey AND
                                         INSERTED.SKU = DELETED.SKU AND
                                         INSERTED.LOC = DELETED.LOC
                        JOIN LOTxLOCxID (NOLOCK) ON LOTxLOCxID.Storerkey = DELETED.Storerkey AND
                                                    LOTxLOCxID.SKU = DELETED.SKU AND
                                                    LOTxLOCxID.LOC = DELETED.LOC
                        JOIN LOC (NOLOCK) ON LOC.LOC = DELETED.LOC
                        WHERE (LOTxLOCxID.Qty - ( LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked )) < 0
                        AND   DELETED.LocationType IN ('CASE', 'PICK')
                        AND   INSERTED.LocationType NOT IN ('CASE', 'PICK')
                        AND   LOC.LocationType IN ('DYNPICKP', 'DYNPICKR') -- SOS140686
                      )
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74907   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed. Qty Over Allocated in LOTxLOCxID (ntrSKUxLOCUpdate)'
            END
         END
         -- (SHONG_20051109) END

         IF @n_continue = 1 OR @n_continue = 2  -- Start (KHLim02)
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspGetRight
                     NULL,             -- facility
                     NULL,             -- Storerkey
                     NULL,             -- Sku
                     'DataMartDELLOG', -- Configkey
                     @b_success     OUTPUT,
                     @c_Authority   OUTPUT,
                     @n_err         OUTPUT,
                     @c_errmsg      OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
                    , @c_errmsg = 'ntrSKUxLOCdelete' + dbo.fnc_RTrim(@c_errmsg)
            END
            ELSE
            IF @c_Authority = '1'
               AND EXISTS ( SELECT 1 FROM DELETED
                            JOIN INSERTED ON INSERTED.Storerkey = DELETED.Storerkey
                            AND INSERTED.SKU = DELETED.SKU
                            AND INSERTED.LOC = DELETED.LOC
                            WHERE DELETED.LocationType IN ('CASE', 'PICK')
                            AND INSERTED.LocationType NOT IN ('CASE', 'PICK') )
            BEGIN
               INSERT INTO dbo.SKUxLOC_DELLOG ( StorerKey, Sku, Loc )
               SELECT DELETED.StorerKey, DELETED.Sku, DELETED.Loc FROM DELETED
               JOIN INSERTED ON INSERTED.Storerkey = DELETED.Storerkey
               AND INSERTED.SKU = DELETED.SKU
               AND INSERTED.LOC = DELETED.LOC
               WHERE DELETED.LocationType IN ('CASE', 'PICK')
               AND INSERTED.LocationType NOT IN ('CASE', 'PICK')

               SELECT @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT On Table SKUxLOC_DELLOG Failed. (ntrSKUxLOCUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
               END
            END
         END -- End (KHLim02)
      END -- UPDATE(LocationType)
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_AllowOverAllocations NVARCHAR(1) -- Flag to see IF overallocations are allowed.

      SELECT @c_AllowOverAllocations = NSQLValue
      FROM NSQLCONFIG WITH (NOLOCK)
      WHERE CONFIGKEY = 'ALLOWOVERALLOCATIONS'

      IF ISNULL(RTRIM(@c_AllowOverAllocations),'') = ''
      BEGIN
         SELECT @c_AllowOverAllocations = '0'
      END
   END

   -- BEGIN ---------------------------------------------------------------------
   DECLARE @c_StorerKey                NVARCHAR(15),
           @c_SKU                      NVARCHAR(20),
           @c_Loc                      NVARCHAR(10),
           @n_PackCaseCnt              float,
           @n_PackPalletCnt            float,
           @n_Qty                      int,
           @n_ReplenishmentSeverity    int,
           @n_QtyReplenishmentOverride int,
           @n_QtyLocationLimit         int,
           @n_QtyPickInProcess         int,
           @n_QtyAllocated             int,
           @c_ReplenishmentPriority    NVARCHAR(5),
           @n_QtyPicked                int,
           @n_QtyExpected              int,
           @n_QtyLocationMinimum       int,
           @c_LocationType             NVARCHAR(10),
           @c_Facility                 NVARCHAR(5),
           @c_LocationHandling         NVARCHAR(10)

   DECLARE @b_topup                    NVARCHAR(1),
           @b_Max_Required             NVARCHAR(1),
           @b_Check_Loc_Handling       NVARCHAR(1)

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_StorerKey = SPACE(15)

      DECLARE C_SKUxLOCUpdStrKy CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT INSERTED.StorerKey,
                 INSERTED.SKU,
                 INSERTED.LOC,
                 INSERTED.ReplenishmentSeverity,
                 INSERTED.QtyReplenishmentOverride,
                 INSERTED.QtyLocationLimit,
                 INSERTED.QtyPickInProcess,
                 INSERTED.QtyPicked,
                 INSERTED.Qty,
                 INSERTED.QtyAllocated,
                 INSERTED.QtyExpected,
                 INSERTED.QtyLocationMinimum,
                 INSERTED.LocationType,
                 LOC.Facility,
                 LOC.LocationHandling
               FROM  INSERTED
               INNER JOIN LOC WITH (NOLOCK) ON (LOC.LOC = INSERTED.LOC)
      ORDER BY INSERTED.StorerKey, INSERTED.SKU, INSERTED.LOC

      OPEN C_SKUxLOCUpdStrKy
      WHILE 1=1  AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         FETCH NEXT FROM C_SKUxLOCUpdStrKy INTO @c_StorerKey, @c_SKU, @c_LOC,
                                                @n_ReplenishmentSeverity,
                                                @n_QtyReplenishmentOverride,
                                                @n_QtyLocationLimit,
                                                @n_QtyPickInProcess,
                                                @n_QtyPicked,
                                                @n_Qty,
                                                @n_QtyAllocated,
                                                @n_QtyExpected,
                                                @n_QtyLocationMinimum,
                                                @c_LocationType,
                                                @c_Facility,
                                                @c_LocationHandling

         IF @@FETCH_STATUS = -1
            BREAK

         ------------ IDS Customisation BEGIN ------------------------------------------------------
         SELECT @b_success = 0

         EXECUTE nspGetRight
                 @c_facility, -- facility
                 @c_Storerkey,   -- Storerkey
                 @c_sku,   -- Sku
                 'ALLOWOVERALLOCATIONS', -- Configkey
                 @b_success              OUTPUT,
                 @c_AllowOverAllocations OUTPUT,
                 @n_err                  OUTPUT,
                 @c_errmsg               OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrPickDetailAdd' + dbo.fnc_RTrim(@c_errmsg)
            BREAK
         END

         EXECUTE nspGetRight @c_facility,  -- Facility
                             @c_storerkey, -- Storer
                             @c_sku,       -- Sku
                             'REPLENISH.PRI TOPUP',      -- ConfigKey
                             @b_success    OUTPUT,
                             @c_Authority  OUTPUT,
                             @n_err        OUTPUT,
                             @c_errmsg     OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @c_errmsg = 'ntrSKUxLOCUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
            BREAK
         END
         ELSE
         BEGIN
            IF @c_Authority = '1'
            BEGIN
               SELECT @b_topup = '1'
            END
            ELSE
            BEGIN
               SELECT @b_topup = '0'
            END
         END

         EXECUTE nspGetRight @c_facility,  -- Facility
                             @c_storerkey, -- Storer
                             @c_sku,       -- Sku
                             'REPLENISH.PRI-LOC MAX REQUIRED',      -- ConfigKey
                             @b_success    OUTPUT,
                             @c_Authority  OUTPUT,
                             @n_err        OUTPUT,
                             @c_errmsg     OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @c_errmsg = 'ntrSKUxLOCUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
            BREAK
         END
         ELSE
         BEGIN
            IF @c_Authority = '1'
            BEGIN
               SELECT @b_Max_Required = '1'
            END
            ELSE
            BEGIN
               SELECT @b_Max_Required = '0'
            END
         END

         EXECUTE nspGetRight @c_facility,  -- Facility
                             @c_storerkey, -- Storer
                             @c_sku,       -- Sku
                             'REPLENISH.SEV-CHECK LOC HANDLE',      -- ConfigKey
                             @b_success    OUTPUT,
                             @c_Authority  OUTPUT,
                             @n_err        OUTPUT,
                             @c_errmsg     OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @c_errmsg = 'ntrSKUxLOCUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
            BREAK
         END
         ELSE
         BEGIN
            IF @c_Authority = '1'
            BEGIN
               SELECT @b_Check_Loc_Handling = '1'
            END
            ELSE
            BEGIN
               SELECT @b_Check_Loc_Handling = '0'
            END
         END
         -------------------------- END of config flag check ------------------------------------

         SELECT @c_ReplenishmentPriority = '9'

         -- SOS# 241110 (Start)
         SET @n_PackCaseCnt   = 0
         SET @n_PackPalletCnt = 0

         SELECT @n_PackCaseCnt = ISNULL(PACK.CaseCnt, 0),
                @n_PackPalletCnt = ISNULL(PACK.Pallet, 0)
         FROM SKU WITH (NOLOCK)
         INNER JOIN PACK WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE SKU.SKU = @c_SKU AND SKU.StorerKey = @c_StorerKey
         -- SOS# 241110 (End)

         IF @c_AllowOverAllocations = '1'
         BEGIN
            -- SOS# 241110 (Start)
            -- SET @n_PackCaseCnt   = 0
            -- SET @n_PackPalletCnt = 0
            --
            -- SELECT @n_PackCaseCnt = ISNULL(PACK.CaseCnt,0),
            --        @n_PackPalletCnt = ISNULL(PACK.Pallet,0)
            -- FROM SKU WITH (NOLOCK)
            -- INNER JOIN PACK WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
            -- WHERE SKU.SKU = @c_SKU AND SKU.StorerKey = @c_StorerKey
            -- SOS# 241110 (End)

            IF @n_PackCaseCnt > 0
            BEGIN
               IF @n_QtyReplenishmentOverride >= @n_PackCaseCnt
                  AND (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) >= 0
                  AND FLOOR((@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))) / @n_PackCaseCnt) > 0
               BEGIN
                  SELECT @c_ReplenishmentPriority = '1'
               END
               ELSE IF @n_QtyReplenishmentOverride >= @n_PackCaseCnt
                       AND (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0
                       AND @b_Max_Required = '1'
                       AND FLOOR((@n_QtyLocationLimit)/@n_PackCaseCnt) > 0
               BEGIN
                  SELECT @c_ReplenishmentPriority = '1'
               END
               ELSE IF @n_QtyPickInProcess > (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))
                       AND @n_QtyExpected > @n_PackCaseCnt
                       AND @n_QtyExpected > 0
                       AND (@n_Qty - @n_QtyExpected) >= 0
                       AND @n_QtyPickInProcess > 0
                       AND @b_Max_Required = '1'
                       AND FLOOR((@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) )/@n_PackCaseCnt) > 0
               BEGIN
                  SELECT @c_ReplenishmentPriority = '2'
               END
               ELSE IF @n_QtyPickInProcess > @n_Qty - (@n_QtyPicked + @n_QtyAllocated)
                       AND @n_QtyExpected > @n_PackCaseCnt
                       AND @n_QtyExpected > 0
                       AND FLOOR((@n_QtyLocationLimit)/@n_PackCaseCnt) > 0
                       AND (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0
                       AND @n_QtyPickInProcess > 0
                       AND @b_Max_Required = '1'
               BEGIN
                  SELECT @c_ReplenishmentPriority = '2'
               END
               ELSE IF @n_QtyExpected > 0
                       AND FLOOR((@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) )/@n_PackCaseCnt) > 0
                       AND (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) >= 0
               BEGIN
                  SELECT @c_ReplenishmentPriority = '3'
               END
               ELSE IF @n_QtyExpected > 0
                       AND FLOOR((@n_QtyLocationLimit)/@n_PackCaseCnt) > 0
                       AND (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0
               BEGIN
                  SELECT @c_ReplenishmentPriority = '3'
               END
               ELSE IF @n_QtyLocationMinimum > (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))
               BEGIN
                  SELECT @c_ReplenishmentPriority = '4'
               END
               ELSE
               BEGIN
                  SELECT @c_ReplenishmentPriority = '9'
               END
            END
            ELSE
            BEGIN
               IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) >= 0
                  AND FLOOR((@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) )) > 0
               BEGIN
                  SELECT @c_ReplenishmentPriority = '1'
               END
               ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0  AND @b_Max_Required = '1'
               BEGIN
                  SELECT @c_ReplenishmentPriority = '1'
               END
               ELSE IF @n_QtyPickInProcess > (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))
                       AND @n_QtyExpected > 0
                       AND @n_Qty - (@n_QtyPicked + @n_QtyAllocated) >= 0
                       AND @n_QtyPickInProcess > 0
                       AND @b_Max_Required = '1'
               BEGIN
                  SELECT @c_ReplenishmentPriority = '2'
               END
               ELSE IF @n_QtyPickInProcess > @n_Qty - (@n_QtyPicked + @n_QtyAllocated)
                       AND @n_QtyExpected > 0
                       AND @n_Qty - (@n_QtyPicked + @n_QtyAllocated) < 0
                       AND @n_QtyPickInProcess > 0
                       AND @b_Max_Required = '1'
               BEGIN
                  SELECT @c_ReplenishmentPriority = '2'
               END
               ELSE IF @n_QtyExpected > 0
                       AND @n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) > 0
                       AND (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) >= 0
               BEGIN
                  SELECT @c_ReplenishmentPriority = '3'
               END
               ELSE IF @n_QtyExpected > 0
                       AND @n_QtyLocationLimit > 0
                       AND (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0
               BEGIN
                  SELECT @c_ReplenishmentPriority = '3'
               END
               ELSE IF @n_QtyLocationMinimum > (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))
               BEGIN
                  SELECT @c_ReplenishmentPriority = '4'
               END
               ELSE
               BEGIN
                  SELECT @c_ReplenishmentPriority = '9'
               END
            END

            -- Assign ReplenishmentSeverity
            -- IF Topping Up was turn on
            IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) >= 0
               AND (@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))) > 0
               AND @n_PackCaseCnt > 0
               AND @n_QtyLocationLimit > 0
               AND @b_topup = '1'
            BEGIN
               SELECT @n_ReplenishmentSeverity =  FLOOR((@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked) )/@n_PackCaseCnt)
            END
            -- When Max Location Limit not setup, use Pallet Count as Max Location Limit
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) >= 0
                     AND (@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))) > 0
                     AND @n_PackPalletCnt > 0
                     AND @n_PackCaseCnt > 0
                     AND @n_QtyLocationLimit = 0
                     AND @b_topup = '1'
            BEGIN
               SELECT @n_ReplenishmentSeverity =  FLOOR((@n_PackPalletCnt - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) )/@n_PackCaseCnt)
            END
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) <= @n_QtyLocationMinimum
                     AND @n_PackCaseCnt > 0
                     AND @n_QtyLocationMinimum > 0
                     AND @n_QtyLocationLimit > 0
                     AND @b_Check_Loc_Handling = '0'
            BEGIN
               SELECT @n_ReplenishmentSeverity = FLOOR(@n_QtyLocationLimit / @n_PackCaseCnt)
            END
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) <= @n_QtyLocationMinimum
                     AND @n_PackCaseCnt > 0
                     AND @n_QtyLocationMinimum > 0
                     AND @n_QtyLocationLimit > 0
                     AND @n_PackPalletCnt > 0
                     AND @b_Check_Loc_Handling = '1'
                     AND @c_LocationHandling = '1' --Pallet Only
            BEGIN
               SELECT @n_ReplenishmentSeverity = FLOOR(FLOOR((@n_QtyLocationLimit - (@n_Qty + (@n_QtyPicked + @n_QtyAllocated))/@n_PackPalletCnt) ) / @n_PackCaseCnt)
            END
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) <= @n_QtyLocationMinimum
                     AND @n_PackCaseCnt > 0
                     AND @n_QtyLocationMinimum > 0
                     AND @n_QtyLocationLimit > 0
                     AND @b_Check_Loc_Handling = '1'
                     AND @c_LocationHandling = '2' --Case Only
                     AND (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0
            BEGIN
               SELECT @n_ReplenishmentSeverity = FLOOR(FLOOR(@n_QtyLocationLimit + ((@n_QtyPicked + @n_QtyAllocated) - @n_Qty)) / @n_PackCaseCnt)
            END
            ELSE IF (@n_Qty - @n_QtyPicked) <= @n_QtyLocationMinimum
                     AND @n_PackCaseCnt > 0
                     AND @n_QtyLocationMinimum > 0
                     AND @n_QtyLocationLimit > 0
                     AND @b_Check_Loc_Handling = '1'
                     AND @c_LocationHandling = '2' --Case Only
            BEGIN
               SELECT @n_ReplenishmentSeverity = FLOOR(FLOOR(@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))) / @n_PackCaseCnt)
            END
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) <= @n_QtyLocationMinimum
                     AND @n_QtyLocationLimit = 0
                     AND @n_PackCaseCnt > 0
                     AND @n_PackPalletCnt > 0
                     AND @b_Check_Loc_Handling = '0'
            BEGIN
               SELECT @n_ReplenishmentSeverity = FLOOR(@n_PackPalletCnt / @n_PackCaseCnt)
            END
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) <= @n_QtyLocationMinimum
                     AND @n_QtyLocationLimit = 0
                     AND @n_PackCaseCnt > 0
                     AND @n_PackPalletCnt > 0
                     AND @b_Check_Loc_Handling = '1'
                     AND @c_LocationHandling = '1' --Pallet Only
            BEGIN
               SELECT @n_ReplenishmentSeverity = FLOOR(@n_PackPalletCnt / @n_PackCaseCnt)
            END
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) <= @n_QtyLocationLimit
                     AND @n_QtyLocationMinimum = 0
                     AND @n_PackCaseCnt > 0
                     AND @n_PackPalletCnt > 0
                     AND @b_Check_Loc_Handling = '1'
                     AND @c_LocationHandling = '1' --Pallet Only
            BEGIN
               SELECT @n_ReplenishmentSeverity = FLOOR(@n_PackPalletCnt / @n_PackCaseCnt)
            END
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) <= @n_QtyLocationMinimum
                     AND ( @n_PackCaseCnt = 0 OR @n_PackCaseCnt IS NULL)
                     AND @n_QtyLocationLimit > 0
                     AND (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0
            BEGIN
               SELECT @n_ReplenishmentSeverity = @n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))
            END
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0
                     AND @n_PackCaseCnt > 0
                     AND @n_QtyLocationLimit > 0
            BEGIN
               SELECT @n_ReplenishmentSeverity = FLOOR(@n_Qtylocationlimit / @n_PackCaseCnt)
            END
            ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0
                     AND @n_PackCaseCnt > 0
            BEGIN
               SELECT @n_ReplenishmentSeverity = FLOOR((@n_QtyLocationLimit )/@n_PackCaseCnt)
            END
            ELSE
            BEGIN
               SELECT @n_ReplenishmentSeverity = 0
            END
         END -- @c_AllowOverAllocations = '1'
         ELSE
         BEGIN
            SELECT @c_ReplenishmentPriority = '9',
                   @n_ReplenishmentSeverity = 0

            IF @n_QtyLocationLimit > (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))
            BEGIN
               SELECT @c_ReplenishmentPriority = '8'

               IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) >= 0
                  AND (@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))) > 0
                  AND (@n_PackCaseCnt > 0)
               BEGIN
                  SELECT @n_ReplenishmentSeverity = FLOOR((@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) )/@n_PackCaseCnt)
               END
               ELSE IF (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) < 0
                        AND (@n_PackCaseCnt > 0)
               BEGIN
                  SELECT @n_ReplenishmentSeverity =  FLOOR((@n_QtyLocationLimit )/@n_PackCaseCnt)
               END
               ELSE
               BEGIN
                  SELECT @n_ReplenishmentSeverity =0
               END
            END -- IF @n_QtyLocationLimit > (@n_Qty - (@n_QtyPicked + @n_QtyAllocated))
         END -- @c_AllowOverAllocations = '0'

         /*
         IF EXISTS(SELECT 1 FROM ORDERDETAIL (nolock)
                   WHERE ORDERDETAIL.STORERKEY = @c_StorerKey
                     AND ORDERDETAIL.sku = @c_SKU
                     AND ORDERDETAIL.openQty > 0
                     AND ORDERDETAIL.openQty - ORDERDETAIL.QtyPicked - ORDERDETAIL.Qtyallocated > 0) AND
            (@c_LocationType = 'PICK' OR @c_LocationType = 'CASE')
         BEGIN
            SELECT @c_ReplenishmentPriority = '7'
            IF ((@n_Qty - @n_QtyPicked) >= 0) AND
               (@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) > 0 AND
               (@n_PackCaseCnt > 0)
               SELECT @n_ReplenishmentSeverity =
                          FLOOR((@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked) )/@n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) < 0 AND
                    (@n_PackCaseCnt > 0)
               SELECT @n_ReplenishmentSeverity = FLOOR((@n_QtyLocationLimit )/@n_PackCaseCnt)
            ELSE
               SELECT @n_ReplenishmentSeverity = 0
         END -- IF exists in orderdetail
        */


         /*       -- commented out to prevent replen of pick location which are not below minimum
         wally 4.dec.03

         IF @n_QtyReplenishmentOverride >= @n_PackCaseCnt AND
            @n_PackCaseCnt > 0 AND (@n_Qty - @n_QtyPicked) >= 0
         BEGIN
            IF FLOOR((@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked) )/ @n_PackCaseCnt) > 0
               SELECT @c_ReplenishmentPriority = '1'
         END
         ELSE IF @n_QtyReplenishmentOverride >= @n_PackCaseCnt AND
                 @n_PackCaseCnt > 0 AND (@n_Qty - @n_QtyPicked) < 0
         BEGIN
            IF FLOOR((@n_QtyLocationLimit) / @n_PackCaseCnt) > 0
               SELECT @c_ReplenishmentPriority = '1'
         END
         ELSE IF @n_QtyPickInProcess > 0 AND
                 @n_Qty - @n_QtyPicked <= @n_QtyLocationMinimum
            SELECT @c_ReplenishmentPriority = '2'
         ELSE IF @n_QtyPicked > 0 AND
                 @n_Qty - @n_QtyPicked <= @n_QtyLocationMinimum
            SELECT @c_ReplenishmentPriority = '3'
         ELSE IF @n_Qtyallocated > 0 AND
              @n_Qty -  @n_QtyPicked <= @n_QtyLocationMinimum
             SELECT @c_ReplenishmentPriority = '4'
         ELSE IF @n_QtyPickInProcess > 0
             SELECT @c_ReplenishmentPriority = '5'
         ELSE IF @n_Qtyallocated > 0
             SELECT @c_ReplenishmentPriority = '6'

         IF (@n_Qty - @n_QtyPicked) >= 0 AND
            (@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) > 0 AND
            (@n_PackCaseCnt > 0)
            SELECT @n_ReplenishmentSeverity =
                        FLOOR((@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked) )/@n_PackCaseCnt)
         ELSE IF (@n_Qty - @n_QtyPicked) < 0 AND
                 (@n_PackCaseCnt > 0)
            SELECT @n_ReplenishmentSeverity = FLOOR((@n_QtyLocationLimit )/@n_PackCaseCnt)
         ELSE
            SELECT @n_ReplenishmentSeverity = 0
         */
         IF @n_ReplenishmentSeverity = 0
            SELECT @c_ReplenishmentPriority = '9'

         IF @n_PackCaseCnt = 0 OR @n_PackCaseCnt IS NULL
            SELECT @n_PackCaseCnt = 1

         UPDATE SKUxLOC  
            SET ReplenishmentSeverity = @n_ReplenishmentSeverity,
                ReplenishmentPriority = @c_ReplenishmentPriority,
                ReplenishmentCaseCnt  = @n_PackCaseCnt
         WHERE  StorerKey = @c_StorerKey
         AND    SKU = @c_SKU
         AND    LOC = @c_LOC

      END -- while storerkey
      CLOSE C_SKUxLOCUpdStrKy
      DEALLOCATE C_SKUxLOCUpdStrKy
   END -- @n_continue=1 OR 2
   -- END ---------------------------------------------------------------------

   /* #INCLUDE <TRSLU2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process AND Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit AND raise an error back to parent, let the parent decide

         -- Commit until the level we BEGIN with
         -- Notes: Original codes do not have COMMIT TRAN, error will be handled by parent
         -- WHILE @@TRANCOUNT > @n_starttcnt
         --    COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrSKUxLOCUpdate'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- Trigger

GO