SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_Populate_Load_By_PickSlip                      */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Insert into Loadplan/Update Loadkey and Scan-out            */
/*                                                                      */
/* Called By: ntrOrderScanAdd                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 29-JUN-2005  Shong         Performance Tunning                       */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/*                                                                      */
/************************************************************************/
CREATE PROC [dbo].[isp_Populate_Load_By_PickSlip]
   @c_LoadKey NVARCHAR(10),
   @c_PickslipNo NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TraceInfo
   declare    @c_starttime            datetime,
              @c_endtime              datetime,
              @c_step1                datetime,
              @c_step2                datetime,
              @c_step3                datetime,
              @c_step4                datetime,
              @c_step5                datetime
   -- TraceInfo
 
   -- Step 1
   set @c_starttime = getdate()

   DECLARE @c_OrderKey            NVARCHAR(10),
            @n_LineNo             int,
            @c_LineNo             NVARCHAR(5),
            @n_err                int,
            @c_errmsg             NVARCHAR(255),
            @c_PickDetailKey      NVARCHAR(10)
	,        @n_starttcnt          int
   ,        @c_Consigneekey       NVARCHAR(15) 
   ,        @c_ExternOrderKey     NVARCHAR(50)    --tlting_ext
   ,        @c_Status             NVARCHAR(10)
   ,        @c_Company            NVARCHAR(45) 

	 -- SOS38254, comment by June 02.AUG.2005
   -- Clean all the tran_count
   --WHILE @@TRANCOUNT > 0
   --BEGIN
   --   COMMIT TRAN 
   --END

   
   SELECT @n_starttcnt=@@TRANCOUNT
   SET @c_step1 = getdate()
   
   DECLARE ScanAddCur Cursor READ_ONLY FAST_FORWARD FOR
   SELECT Distinct ORDERS.OrderKey, ORDERS.Consigneekey, 
          ORDERS.ExternOrderKey, ORDERS.Status, ORDERS.c_Company
   FROM   PickDetail (NOLOCK) 
   JOIN   ORDERS (NOLOCK) ON ORDERS.OrderKey = PickDetail.OrderKey 
   WHERE  PickDetail.PickslipNo = @c_PickslipNo  
   ORDER BY ORDERS.OrderKey

   OPEN ScanAddCur

   FETCH NEXT FROM ScanAddCur INTO @c_OrderKey, @c_Consigneekey, @c_ExternOrderKey, @c_Status, @c_Company

   WHILE (@@Fetch_Status <> -1)
   BEGIN -- OrderKey loop
      IF NOT EXISTS (SELECT 1 FROM LOADPLANDETAIL (nolock) WHERE LoadKey = @c_LoadKey AND OrderKey = @c_OrderKey)
      BEGIN 
         SELECT @n_LineNo = ISNULL(MAX(LoadLineNumber),0) 
         FROM  LOADPLANDETAIL (NOLOCK) 
         WHERE LoadKey = @c_LoadKey
   
   		SELECT @c_LineNo = dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(5), @n_LineNo + 1))) -- New line number
   		SELECT @c_LineNo = REPLICATE('0', 5 - LEN(@c_LineNo)) + @c_LineNo

         BEGIN TRAN

         INSERT INTO LOADPLANDETAIL (LoadKey, LoadLineNumber, OrderKey, Consigneekey, ExternOrderKey, 
                           Status, CustomerName) VALUES
   		   (@c_LoadKey, @c_LineNo, @c_OrderKey, @c_Consigneekey, @c_ExternOrderKey, @c_Status, @c_Company)
   		
         SELECT @n_err = @@ERROR
         if @n_err = 0
         BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt COMMIT TRAN 
         END 
         ELSE
         BEGIN
            SELECT @c_errmsg = 'Insert into LOADPLANDETAIL Failed. (isp_Populate_Load_By_PickSlip)'
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            ROLLBACK TRAN
            RETURN 1
         END
      END

      IF EXISTS (SELECT 1 FROM ORDERDETAIL (nolock) WHERE OrderKey = @c_OrderKey AND 
                (ISNULL(dbo.fnc_RTrim(LoadKey), 0) = 0 OR dbo.fnc_RTrim(LoadKey) = ''))
      BEGIN
         BEGIN TRAN

         UPDATE OD
         SET TRAFFICCOP = NULL,
             LoadKey = @c_LoadKey,
             EditWho = sUser_sName(),
             EditDate = Getdate() 
         FROM ORDERDETAIL od 
         JOIN PickDetail P (nolock) ON OD.OrderKey = P.OrderKey AND OD.OrderLineNumber = P.OrderLineNumber 
         WHERE P.PickslipNo = @c_PickslipNo
           AND P.OrderKey = @c_OrderKey

         SELECT @n_err = @@ERROR
         if @n_err = 0
         BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt COMMIT TRAN
         END
         ELSE
         BEGIN
            SELECT @c_errmsg = 'Update Failed ON OrderDetail. (isp_Populate_Load_By_PickSlip)'
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            ROLLBACK TRAN
            RETURN 1
         END
      END -- IF EXISTS 


--       SELECT @c_PickDetailKey = ''
-- 
--       DECLARE Pick_Cur CURSOR READ_ONLY FAST_FORWARD FOR 
--       SELECT PickDetailKey 
--       FROM PickDetail (NOLOCK)
--       WHERE PickslipNo = @c_PickslipNo
--         AND OrderKey = @c_OrderKey 
--         AND Status = '0'
--       ORDER BY PickDetailKey 
-- 
--       OPEN Pick_Cur 
-- 
--       FETCH NEXT FROM Pick_Cur INTO @c_PickDetailKey
--       WHILE (@@FETCH_STATUS <> -1)
--       BEGIN -- PickDetail loop
--          BEGIN TRAN
-- 
--          UPDATE PickDetail with (ROWLOCK) 
--          set status = '5'
--          WHERE PickDetailKey = @c_PickDetailKey
-- 
--          SELECT @n_err = @@ERROR
--          if @n_err = 0
--          BEGIN
--             WHILE @@TRANCOUNT > @n_starttcnt COMMIT TRAN
--          END
--          ELSE
--          BEGIN
--             SELECT @c_errmsg = 'Update Failed ON PickDetail. (isp_Populate_Load_By_PickSlip)'
--             RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
--             ROLLBACK TRAN
--             RETURN 1
--          END      
--          FETCH NEXT FROM Pick_Cur INTO @c_PickDetailKey    
--       END -- PickDetail loop
--       CLOSE Pick_Cur
--       DEALLOCATE Pick_Cur 

      FETCH NEXT FROM ScanAddCur INTO @c_OrderKey, @c_Consigneekey, @c_ExternOrderKey, @c_Status, @c_Company
   END -- OrderKey loop
   CLOSE ScanAddCur
   DEALLOCATE ScanAddCur 

   -- Step 1
   set @c_step1 = getdate() - @c_step1
 

   set @c_step2 = getdate()
   -- auto-scan out
   if exists(SELECT 1 FROM PickDetail (nolock) WHERE PickslipNo = @c_PickslipNo
                     AND   status = '0' )
   BEGIN 
      BEGIN TRAN
      update PickDetail with (rowlock) 
         set status = '5'
      WHERE PickslipNo = @c_PickslipNo 
      AND   status = '0' 
      
      SELECT @n_err = @@ERROR
      if @n_err = 0
         COMMIT TRAN
      ELSE
      BEGIN
         SELECT @c_errmsg = 'Update Failed ON PickDetail. (isp_Populate_Load_By_PickSlip)'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         rollback tran
         RETURN 1
      end      
   end

   set @c_step2 = getdate() - @c_step2

   set @c_step3 = getdate()
   -- update scanoutdate - this will not execute the trigger since zone = 'W'
   BEGIN TRAN

   UPDATE PICKINGINFO
   SET SCANOUTDATE = GETDATE(), TrafficCop = NULL 
   WHERE PICKSLIPNO = @C_PICKSLIPNO

   SELECT @n_err = @@ERROR
   IF @n_err = 0
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt COMMIT TRAN
   END
   ELSE
   BEGIN
      SELECT @c_errmsg = 'Update Failed ON PickingInfo. (isp_Populate_Load_By_PickSlip)'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      ROLLBACK TRAN
      RETURN 1
   END 

   set @c_step3 = getdate() - @c_step3
--    BEGIN TRAN
--         set @c_endtime = getdate()
--         INSERT INTO TraceInfo VALUES
--         ('isp_Populate_Load_By_PickSlip,'+@c_LoadKey+','+@c_PickslipNo,@c_starttime,@c_endtime,
--          convert(char(12),@c_endtime-@c_starttime ,114),
--          convert(char(12),@c_step1,114),convert(char(12),@c_step2,114),
--          convert(char(12),@c_step3,114),convert(char(12),@c_step4,114),
--          convert(char(12),@c_step5,114))
--    COMMIT TRAN

END

GO