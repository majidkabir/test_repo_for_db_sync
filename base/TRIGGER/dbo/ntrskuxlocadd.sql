SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ntrSKUxLOCAdd                                              */
/* Creation Date: 22-Mar-2006                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Trigger point upon any insertion on SKUxLOC                */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 06-May-2008  SHONG     Not allow to update if Over-Allocated qty     */
/*                        found in LOTxLOCxID (SHONG_20080506)          */
/* 23-Aug-2016  TLTING    add NOLOCK hint                               */
/* 30-Mar-2021  NJOW01    WMS-16618 call custom stored proc             */ 
/************************************************************************/
CREATE TRIGGER [dbo].[ntrSKUxLOCAdd]
ON  [dbo].[SKUxLOC]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
             @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err                int       -- Error number returned by stored procedure or this trigger
   ,         @n_err2       int               -- For Additional Error Detection
   ,         @c_errmsg     NVARCHAR(250)         -- Error message returned by stored procedure or this trigger
   ,         @n_continue   int
   ,         @n_starttcnt  int                -- Holds the current transaction count
   ,         @c_PreProcess NVARCHAR(250)         -- preprocess
   ,         @c_PstProcess NVARCHAR(250)         -- post process
   ,         @n_cnt int
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF EXISTS(SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

    /* #INCLUDE <TRSLU1.SQL> */
   -- (SHONG_20051109) - don't run this if 1st check was failed 
   IF @n_continue = 1 or @n_continue = 2 
   BEGIN
      -- Check is location lose id
      IF EXISTS ( SELECT INSERTED.LOC FROM INSERTED
                  JOIN   LOC (NOLOCK) ON LOC.LOC = INSERTED.LOC
                  WHERE INSERTED.LocationType IN ('CASE', 'PICK')
                  AND   LOC.LoseID = '0'
      )
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74907   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Assign Pick/Case Location Not Allow. Please Set Location to Lose Id (ntrSKUxLOCUpdate)' 
      END
   END

   --NJOW01 S
   IF @n_continue=1 or @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED i
                 JOIN storerconfig s WITH (NOLOCK) ON  i.StorerKey = s.StorerKey
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'SKUXLOCTrigger_SP')
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
                   'INSERT'  --@c_Action
                 , @b_Success  OUTPUT
                 , @n_Err      OUTPUT
                 , @c_ErrMsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrSKUxLOCAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END

         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END
   --NJOW01 E

-- begin ---------------------------------------------------------------------
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
           @n_Qtyexpected              int,
           @n_QtyLocationMinimum       int,
           @c_LocationType             NVARCHAR(10),
           @c_Facility                 NVARCHAR(5),
           @c_LocationHandling         NVARCHAR(10)

   Declare @b_topup              NVARCHAR(1), 
           @b_max_required       NVARCHAR(1), 
           @b_check_loc_handling NVARCHAR(1),
           @c_authority          NVARCHAR(1)

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_StorerKey = SPACE(15)
      
      DECLARE C_SKUxLOCUpdStrKy CURSOR LOCAL FAST_FORWARD READ_ONLY
      FOR SELECT INSERTED.StorerKey, 
                 INSERTED.SKU, 
                 INSERTED.LOC,
                 INSERTED.ReplenishmentSeverity,
                 INSERTED.QtyReplenishmentOverride,
                 INSERTED.QtyLocationLimit,
                 INSERTED.QtyPickInProcess,
                 ISNULL(PACK.CaseCnt,0),
                 ISNULL(PACK.Pallet,0),
                 INSERTED.QtyPicked,
                 INSERTED.Qty,
                 INSERTED.QtyAllocated,
                 INSERTED.QtyExpected,
                 INSERTED.QtyLocationMinimum,
                 INSERTED.LocationType,
                 LOC.Facility,
                 LOC.LocationHandling    
               FROM  INSERTED 
               INNER JOIN dbo.SKU WITH (NOLOCK) ON (SKU.SKU = INSERTED.SKU AND SKU.StorerKey = INSERTED.StorerKey)
               INNER JOIN dbo.PACK WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
               INNER JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = INSERTED.LOC)
               WHERE INSERTED.LocationType IN ('CASE', 'PICK')  
      ORDER BY INSERTED.StorerKey, INSERTED.SKU, INSERTED.LOC 
   
      OPEN C_SKUxLOCUpdStrKy

      WHILE 1=1  AND (@n_continue = 1 OR @n_continue = 2) 
      BEGIN
         FETCH NEXT FROM C_SKUxLOCUpdStrKy INTO @c_StorerKey, @c_SKU, @c_LOC, 
               @n_ReplenishmentSeverity, 
               @n_QtyReplenishmentOverride,
               @n_QtyLocationLimit,
               @n_QtyPickInProcess,
               @n_PackCaseCnt,
               @n_PackPalletCnt, 
               @n_QtyPicked,
               @n_Qty, 
               @n_QtyAllocated, 
               @n_Qtyexpected,
               @n_QtyLocationMinimum, 
               @c_LocationType, 
               @c_Facility, 
               @c_LocationHandling
         
         IF @@FETCH_STATUS = -1 
            BREAK   

         Execute nspGetRight @c_facility,  -- Facility
                             @c_storerkey, -- Storer
                             @c_sku,       -- Sku
                             'REPLENISH.PRI TOPUP',      -- ConfigKey
                             @b_success    output, 
                             @c_authority  output, 
                             @n_err        output, 
                             @c_errmsg     output
         If @b_success <> 1
         Begin
            Select @c_errmsg = 'ntrSKUxLOCUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
            Break
         End
         Else 
         Begin
            If @c_authority = '1'
               Select @b_topup = '1'
            Else
               Select @b_topup = '0'
         End

         Execute nspGetRight @c_facility,  -- Facility
                             @c_storerkey, -- Storer
                             @c_sku,       -- Sku
                             'REPLENISH.SEV-CHECK LOC HANDLE',      -- ConfigKey
                             @b_success    output, 
                             @c_authority  output, 
                             @n_err        output, 
                             @c_errmsg     output
         If @b_success <> 1
         Begin
            Select @c_errmsg = 'ntrSKUxLOCUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
            Break
         End
         Else 
         Begin
            If @c_authority = '1'
               Select @b_check_loc_handling = '1'
            Else
               Select @b_check_loc_handling = '0'
         End

         Execute nspGetRight @c_facility,  -- Facility
                             @c_storerkey, -- Storer
                             @c_sku,       -- Sku
                             'REPLENISH.PRI-LOC MAX REQUIRED',      -- ConfigKey
                             @b_success    output, 
                             @c_authority  output, 
                             @n_err        output, 
                             @c_errmsg     output
         If @b_success <> 1
         Begin
            Select @c_errmsg = 'ntrSKUxLOCUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
            Break
         End
         Else 
         Begin
            If @c_authority = '1'
               Select @b_max_required = '1'
            Else
               Select @b_max_required = '0'
         End

         SELECT @c_ReplenishmentPriority = '9'
    
            -- Assign ReplenishmentSeverity
            -- If Topping Up was turn on 
            IF (@n_Qty - @n_QtyPicked) >= 0
               and (@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) > 0
               and @n_PackCaseCnt > 0
               and @n_QtyLocationLimit > 0 
               and @b_topup = '1'
                  SELECT @n_ReplenishmentSeverity =  FLOOR((@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked) )/@n_PackCaseCnt)
            -- When Max Location Limit not setup, use Pallet Count as Max Location Limit 
            ELSE IF (@n_Qty - @n_QtyPicked) >= 0
               and (@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) > 0
               and @n_PackPalletCnt > 0
               and @n_PackCaseCnt > 0
               and @n_QtyLocationLimit = 0
               and @b_topup = '1'
                  SELECT @n_ReplenishmentSeverity =  FLOOR((@n_PackPalletCnt - (@n_Qty - @n_QtyPicked) )/@n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) <= @n_QtyLocationMinimum
               and @n_PackCaseCnt > 0
               and @n_QtyLocationMinimum > 0
               and @n_QtyLocationLimit > 0 
               and @b_check_loc_handling = '0'
                  SELECT @n_ReplenishmentSeverity = FLOOR(@n_QtyLocationLimit / @n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) <= @n_QtyLocationMinimum
               AND @n_PackCaseCnt > 0
               AND @n_QtyLocationMinimum > 0
               AND @n_QtyLocationLimit > 0
               AND @n_PackPalletCnt > 0
               AND @b_check_loc_handling = '1'
               AND @c_LocationHandling = '1' --Pallet Only
                  SELECT @n_ReplenishmentSeverity = FLOOR(FLOOR((@n_QtyLocationLimit - (@n_Qty + @n_QtyPicked)/@n_PackPalletCnt) ) / @n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) <= @n_QtyLocationMinimum
               AND @n_PackCaseCnt > 0
               AND @n_QtyLocationMinimum > 0
               AND @n_QtyLocationLimit > 0
               and @b_check_loc_handling = '1'
               AND @c_LocationHandling = '2' --Case Only
               AND (@n_Qty - @n_QtyPicked) < 0
                  SELECT @n_ReplenishmentSeverity = FLOOR(FLOOR(@n_QtyLocationLimit + (@n_QtyPicked - @n_Qty)) / @n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) <= @n_QtyLocationMinimum
               AND @n_PackCaseCnt > 0
               AND @n_QtyLocationMinimum > 0
               AND @n_QtyLocationLimit > 0
               and @b_check_loc_handling = '1'
               AND @c_LocationHandling = '2' --Case Only
                  SELECT @n_ReplenishmentSeverity = FLOOR(FLOOR(@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) / @n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) <= @n_QtyLocationMinimum
               and @n_QtyLocationLimit = 0
               and @n_PackCaseCnt > 0
               and @n_PackPalletCnt > 0
               and @b_check_loc_handling = '0'
                  SELECT @n_ReplenishmentSeverity = FLOOR(@n_PackPalletCnt / @n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) <= @n_QtyLocationMinimum
               AND @n_QtyLocationLimit = 0
               AND @n_PackCaseCnt > 0
               AND @n_PackPalletCnt > 0
               and @b_check_loc_handling = '1'
               AND @c_LocationHandling = '1' --Pallet Only
                  SELECT @n_ReplenishmentSeverity = FLOOR(@n_PackPalletCnt / @n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) <= @n_QtyLocationLimit
               AND @n_QtyLocationMinimum = 0
               AND @n_PackCaseCnt > 0
               AND @n_PackPalletCnt > 0
               and @b_check_loc_handling = '1'
               AND @c_LocationHandling = '1' --Pallet Only
                  SELECT @n_ReplenishmentSeverity = FLOOR(@n_PackPalletCnt / @n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) <= @n_QtyLocationMinimum
               AND ( @n_PackCaseCnt = 0 OR @n_PackCaseCnt IS NULL)
               AND @n_QtyLocationLimit > 0
               AND (@n_Qty - @n_QtyPicked) < 0
                  SELECT @n_ReplenishmentSeverity = @n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)
            ELSE IF (@n_Qty - @n_QtyPicked) < 0
               and @n_PackCaseCnt > 0
               and @n_QtyLocationLimit > 0
                  SELECT @n_ReplenishmentSeverity = FLOOR(@n_Qtylocationlimit / @n_PackCaseCnt)
            ELSE IF (@n_Qty - @n_QtyPicked) < 0
                 and @n_PackCaseCnt > 0
               SELECT @n_ReplenishmentSeverity = FLOOR((@n_QtyLocationLimit )/@n_PackCaseCnt)
            ELSE 
               SELECT @n_ReplenishmentSeverity = 0
   
         IF @n_ReplenishmentSeverity = 0
            SELECT @c_ReplenishmentPriority = '9'
         
         IF @n_PackCaseCnt = 0 OR @n_PackCaseCnt IS NULL 
            SELECT @n_PackCaseCnt = 1
         
         UPDATE SKUxLOC WITH (ROWLOCK)
            SET ReplenishmentSeverity = @n_ReplenishmentSeverity,
                ReplenishmentPriority = @c_ReplenishmentPriority,
                ReplenishmentCaseCnt  = @n_PackCaseCnt,
                TrafficCop = NULL 
         WHERE  StorerKey = @c_StorerKey
         AND    SKU = @c_SKU
         AND    LOC = @c_LOC
         
         --NJOW01


      END -- while storerkey
      CLOSE C_SKUxLOCUpdStrKy
      DEALLOCATE C_SKUxLOCUpdStrKy
   END -- @n_continue=1 or 2
-- End -------------------------------------------------------------

/* #INCLUDE <TRSLU2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
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
   execute nsp_logerror @n_err, @c_errmsg, 'ntrSKUxLOCAdd'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END -- Trigger 

GO