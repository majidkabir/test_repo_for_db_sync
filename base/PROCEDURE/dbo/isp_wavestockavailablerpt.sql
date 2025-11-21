SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: isp_WaveStockAvailableRpt                                */
/* Creation Date: 10-Jul-2012                                                 */
/* Copyright: IDS                                                             */
/* Written by: YTWan                                                          */
/*                                                                            */
/* Purpose:  SOS#248756-Stock Availability Report                             */
/*                                                                            */
/* Called By:  r_dw_stock_availability_wave                                   */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author     Ver   Purposes                                     */   
/******************************************************************************/

CREATE PROC [dbo].[isp_WaveStockAvailableRpt] (
            @c_WaveKey  NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE  @b_debug          INT 

   DECLARE  @n_Continue       INT
         ,  @n_StartTCnt      INT
         ,  @b_Success        INT
         ,  @n_Err            INT
         ,  @c_Errmsg         NVARCHAR(255)

         ,  @c_ExecSQLStmt    NVARCHAR(MAX)
         ,  @c_ExecArguments  NVARCHAR(MAX)
      
         ,  @n_Cnt            INT
         ,  @c_Facility       NVARCHAR(5)
         ,  @c_StorerKey      NVARCHAR(15)
         ,  @c_OrderKey       NVARCHAR(10)
         ,  @c_Sku            NVARCHAR(20) 
         ,  @c_Lottable01     NVARCHAR(18)
         ,  @c_Lottable02     NVARCHAR(18)
         ,  @c_Lottable03     NVARCHAR(18)
         ,  @n_OriginalQty    INT
         ,  @n_AllOriginalQty INT
         ,  @n_QtyAvailable   INT
         ,  @n_QtyHoldLT48H   INT
         ,  @n_QtyHoldGT48H   INT
         ,  @n_QtyNoneLT48H   INT
         ,  @n_QtyNoneGT48H   INT

   SET @b_debug         = 0
   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT
   SET @b_Success       = 1
   SET @c_Errmsg        = ''
   SET @c_ExecSQLStmt   = ''
   SET @c_ExecArguments = ''
   SET @n_Cnt           = 1

   SET @c_Facility      = ''
   SET @c_StorerKey     = ''
   SET @c_OrderKey      = ''
   SET @c_Sku           = ''
   SET @c_Lottable01    = ''
   SET @c_Lottable02    = ''
   SET @c_Lottable03    = ''
   SET @n_OriginalQty   = 0
   SET @n_AllOriginalQty= 0
   SET @n_QtyAvailable  = 0
   SET @n_QtyHoldLT48H  = 0
   SET @n_QtyHoldGT48H  = 0
   SET @n_QtyNoneLT48H  = 0
   SET @n_QtyNoneGT48H  = 0

   CREATE TABLE #TempStock
               (  SeqNo          INT         NOT NULL IDENTITY(1,1)
               ,  Facility       NVARCHAR(5)
               ,  Storerkey      NVARCHAR(15)
               ,  OrderKey       NVARCHAR(10)
               ,  Sku            NVARCHAR(20)
               ,  Lottable01     NVARCHAR(18)
               ,  Lottable02     NVARCHAR(18)
               ,  Lottable03     NVARCHAR(18)
               ,  OriginalQty    INT
               ,  AllOriginalQty INT
               ,  QtyAvailable   INT
               ,  QtyHoldLT48H   INT
               ,  QtyHoldGT48H   INT
               ,  QtyNoneLT48H   INT
               ,  QtyNoneGT48H   INT

               )

   DECLARE ORDERS_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(OH.Facility),'')
         ,ISNULL(RTRIM(OH.Storerkey),'')
         ,ISNULL(RTRIM(OD.Orderkey),'')
         ,ISNULL(RTRIM(OD.Sku),'')
         ,ISNULL(RTRIM(OD.Lottable01),'')
         ,ISNULL(RTRIM(OD.Lottable02),'')
         ,ISNULL(RTRIM(OD.Lottable03),'')
         ,SUM(OD.OriginalQty)
   FROM WAVEDETAIL   WD WITH (NOLOCK)
   JOIN ORDERS       OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey
   GROUP BY ISNULL(RTRIM(OH.Facility),'')
         ,  ISNULL(RTRIM(OH.Storerkey),'')
         ,  ISNULL(RTRIM(OD.Orderkey),'')
         ,  ISNULL(RTRIM(OD.Sku),'')
         ,  ISNULL(RTRIM(OD.Lottable01),'')
         ,  ISNULL(RTRIM(OD.Lottable02),'')
         ,  ISNULL(RTRIM(OD.Lottable03),'')
   ORDER BY ISNULL(RTRIM(OD.Orderkey),'')
         ,  ISNULL(RTRIM(OD.Sku),'')

   OPEN ORDERS_CUR
   FETCH NEXT FROM ORDERS_CUR INTO @c_Facility
                                 , @c_Storerkey
                                 , @c_OrderKey
                                 , @c_Sku       
                                 , @c_Lottable01
                                 , @c_Lottable02
                                 , @c_Lottable03
                                 , @n_OriginalQty

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN 
      SET @n_AllOriginalQty = 0
      SELECT @n_AllOriginalQty = ISNULL(SUM(OD.OriginalQty),0)
      FROM ORDERS OH WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      WHERE OD.Storerkey = @c_Storerkey
      AND   OD.Sku = @c_Sku 
      AND   OD.Lottable01 = @c_Lottable01
      AND   OD.Lottable02 = @c_Lottable02
      AND   OD.Lottable03 = @c_Lottable03
      AND   OH.Status = '0'
      
      SET @n_QtyHoldLT48H = 0
      SET @n_QtyHoldGT48H = 0
      SET @n_QtyNoneLT48H = 0
      SET @n_QtyNoneGT48H = 0
      SELECT @n_QtyHoldLT48H = ISNULL(SUM(CASE WHEN LOC.locationFlag = 'HOLD' 
                                          AND DATEDIFF(hh, ISNULL(LA.Lottable05,CONVERT(DATETIME, '19000101')), GetDate()) <= 48 
                                               THEN LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked ELSE 0 END),0)
            ,@n_QtyHoldGT48H = ISNULL(SUM(CASE WHEN LOC.locationFlag = 'HOLD' 
                                          AND DATEDIFF(hh, ISNULL(LA.Lottable05,CONVERT(DATETIME, '19000101')), GetDate()) > 48 
                                               THEN LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked ELSE 0 END),0)
            ,@n_QtyNoneLT48H = ISNULL(SUM(CASE WHEN LOC.locationFlag = 'NONE' 
                                          AND DATEDIFF(hh, ISNULL(LA.Lottable05,CONVERT(DATETIME, '19000101')), GetDate()) <= 48 
                                               THEN LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked ELSE 0 END),0)
            ,@n_QtyNoneGT48H = ISNULL(SUM(CASE WHEN LOC.locationFlag = 'NONE' 
                                          AND DATEDIFF(hh, ISNULL(LA.Lottable05,CONVERT(DATETIME, '19000101')), GetDate()) > 48 
                                               THEN LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked ELSE 0 END),0)
      FROM LOTATTRIBUTE LA WITH (NOLOCK)         
      JOIN LOTxLOCxID  LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0
      JOIN LOC         LOC WITH (NOLOCK) ON (LLI.Loc = LOC.Loc) AND (LOC.LocationFlag IN ('NONE', 'HOLD'))
      WHERE LA.Storerkey = @c_Storerkey
      AND   LA.Sku = @c_Sku 
      AND   LA.Lottable01 = CASE WHEN @c_Lottable01 = '' THEN LA.Lottable01 ELSE @c_Lottable01 END
      AND   LA.Lottable02 = CASE WHEN @c_Lottable02 = '' THEN LA.Lottable02 ELSE @c_Lottable02 END
      AND   LA.Lottable03 = CASE WHEN @c_Lottable03 = '' THEN LA.Lottable03 ELSE @c_Lottable03 END
  
      SET @n_QtyAvailable = @n_QtyHoldLT48H + @n_QtyHoldGT48H + @n_QtyNoneLT48H + @n_QtyNoneGT48H
         
      INSERT INTO #TempStock
                  ( Facility
                  , Storerkey
                  , OrderKey   
                  , Sku
                  , Lottable01
                  , Lottable02
                  , Lottable03
                  , OriginalQty
                  , AllOriginalQty
                  , QtyAvailable
                  , QtyHoldLT48H
                  , QtyHoldGT48H
                  , QtyNoneLT48H
                  , QtyNoneGT48H       
                  )
      VALUES      ( @c_Facility
                  , @c_Storerkey
                  , @c_OrderKey   
                  , @c_Sku
                  , @c_Lottable01
                  , @c_Lottable02
                  , @c_Lottable03
                  , @n_OriginalQty
                  , @n_AllOriginalQty
                  , @n_QtyAvailable
                  , @n_QtyHoldLT48H
                  , @n_QtyHoldGT48H
                  , @n_QtyNoneLT48H
                  , @n_QtyNoneGT48H  
                  )

      FETCH NEXT FROM ORDERS_CUR INTO @c_Facility
                                    , @c_Storerkey
                                    , @c_OrderKey
                                    , @c_Sku       
                                    , @c_Lottable01
                                    , @c_Lottable02
                                    , @c_Lottable03
                                    , @n_OriginalQty
   END 
   CLOSE ORDERS_CUR
   DEALLOCATE ORDERS_CUR

   SELECT  Wavekey= @c_WaveKey                                                 
         , #TempStock.Facility     
         , #TempStock.Storerkey
         , #TempStock.OrderKey   
         , #TempStock.Sku
         , #TempStock.Lottable01
         , #TempStock.Lottable02
         , #TempStock.Lottable03
         , #TempStock.OriginalQty
         , #TempStock.AllOriginalQty
         , #TempStock.QtyAvailable
         , #TempStock.QtyHoldLT48H
         , #TempStock.QtyHoldGT48H
         , #TempStock.QtyNoneLT48H
         , #TempStock.QtyNoneGT48H   
         , UserID = SUSER_NAME()                                                     
   FROM #TempStock
   ORDER BY #TempStock.SeqNo

   DROP TABLE #TempStock
END

GO