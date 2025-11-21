SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_OrderInfo_Update_Rpt                           */
/* Creation Date: 28-SEP-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15142 CN IKEA VIEWREPORT ORDERINFO UPDATING             */
/*                                                                      */
/* Called By: r_OrderInfo_Update_Rpt                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 18-Aug-2023  WLChooi 1.1   WMS-23376 - Add new logic (WL01)          */
/* 18-Aug-2023  WLChooi 1.1   DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[isp_OrderInfo_Update_Rpt]
   @c_storerkey      NVARCHAR(20)
 , @c_facility       NVARCHAR(15)
 , @c_StartOrderDate NVARCHAR(45)
 , @c_EndOrderDate   NVARCHAR(45)
 , @c_hostwhcode     NVARCHAR(10) = ''
 , @c_courier        NVARCHAR(45) = ''
AS
BEGIN
   SET NOCOUNT ON -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug INT = 0;
   DECLARE @c_TargetNum NVARCHAR(10);
   -- DECLARE @c_StartOrderDate NVARCHAR(20);  
   -- DECLARE @c_EndOrderDate   NVARCHAR(20);  
   DECLARE @c_GetStorerKey NVARCHAR(15);
   DECLARE @Orderkey NVARCHAR(30);

   DECLARE @c_SQL     NVARCHAR(MAX)
         , @c_SQLParm NVARCHAR(MAX);

   DECLARE @n_Continue  INT
         , @n_StartTCnt INT
         , @b_Success   INT
         , @n_Err       INT
         , @c_ErrMsg    NVARCHAR(250);


   DECLARE @c_getOrderkey      NVARCHAR(20)
         , @c_getfacility      NVARCHAR(20)
         , @c_getsku           NVARCHAR(20)
         , @n_ORIQTY           INT
         , @n_AvaiQty          INT
         , @c_replen           NVARCHAR(5)
         , @c_ExecMain         NVARCHAR(4000)
         , @c_ExecStatements   NVARCHAR(4000)
         , @c_OrderdateFilter  NVARCHAR(4000)
         , @c_hostwhcodeFilter NVARCHAR(4000)
         , @c_StoreFilter      NVARCHAR(4000)   --WL01
         , @c_ExecArguments    NVARCHAR(4000)
         , @c_GrpByORD         NVARCHAR(4000)
         , @c_ORDBY            NVARCHAR(4000)
         , @c_GrpByLLISKU      NVARCHAR(4000)
         , @c_ORDERBYORD       NVARCHAR(4000)
         , @c_ErrorMsg         NVARCHAR(150)
         , @n_INVQTY           INT
         , @n_AVLQTY           INT
         , @n_AllocQty         INT
         , @n_getAvlqty        INT

   SET @c_ErrorMsg = N''

   CREATE TABLE #TMPORD
   (
      RowID     INT IDENTITY(1, 1)
    , Storerkey NVARCHAR(20)
    , Orderkey  NVARCHAR(20)
    , SKU       NVARCHAR(20)
    , Facility  NVARCHAR(10)
    , OHADDDATE DATETIME
    , ORIQTY    INT
    , REPLEN    NVARCHAR(10)
   )

   CREATE TABLE #TMPINV
   (
      RowID     INT IDENTITY(1, 1)
    , Storerkey NVARCHAR(20)
    , sku       NVARCHAR(20)
    , Facility  NVARCHAR(20)
    , AVAILQTY  INT
   )

   CREATE TABLE #TMPORDERUP
   (
      RowID        INT           IDENTITY(1, 1)
    , Storerkey    NVARCHAR(20)
    , ORDERKEY     NVARCHAR(20)  NULL
    , sku          NVARCHAR(20)  NULL
    , Facility     NVARCHAR(10)
    , ORIQTY       INT           NULL
    , AVAILQTY     INT           NULL
    , OrdStartDate DATETIME
    , OrderEndDate DATETIME
    , hostwhcode   NVARCHAR(10)
    , courier      NVARCHAR(45)
    , ErrMsg       NVARCHAR(150) NULL
   )

   CREATE TABLE #TMPORDTBL
   (
      RowID     INT IDENTITY(1, 1)
    , Storerkey NVARCHAR(20)
    , Orderkey  NVARCHAR(20)
    , SKU       NVARCHAR(20)
    , Facility  NVARCHAR(10)
    , ORIQTY    INT
    , INVQTY    INT
    , AVLQTY    INT
    , CANREPLEN NVARCHAR(10)
   )

   CREATE TABLE #TMPORDTBL1
   (
      RowID     INT IDENTITY(1, 1)
    , Storerkey NVARCHAR(20)
    , Orderkey  NVARCHAR(20)
    , Facility  NVARCHAR(10),
   )

   IF ISNULL(@c_storerkey, '') = '' OR ISNULL(@c_facility, '') = ''
   BEGIN
      SET @c_ErrorMsg = N'Input parameter for Facility or Storerkey cannot be NULL '
      GOTO QUIT_SP
   END

   SET @c_OrderdateFilter = N''
   IF ISNULL(@c_StartOrderDate, '') <> '' AND ISNULL(@c_EndOrderDate, '') <> ''
   BEGIN


      IF DATEDIFF(DAY, CAST(@c_StartOrderDate AS DATETIME), CAST(@c_EndOrderDate AS DATETIME)) > 2
      BEGIN
         SET @c_ErrorMsg = N'Input Date more than 2 days'
         GOTO QUIT_SP
      END
      -- print '@c_ErrorMsg : ' + @c_ErrorMsg 

      SET @c_OrderdateFilter = N' AND OD.Adddate BETWEEN CAST(@c_StartOrderDate as DATETIME)  AND CAST(@c_ENDOrderDate as DATETIME) '

   -- print '@c_OrderdateFilter ' +  @c_OrderdateFilter    
   END
   ELSE
   BEGIN
      SET @c_ErrorMsg = N'Input Date cannot be blank'
      GOTO QUIT_SP
   END

   --IF ISNULL(@c_ErrorMsg,'') = ''
   --BEGIN
   SET @c_hostwhcodeFilter = N''
   IF ISNULL(@c_hostwhcode, '') <> ''
   BEGIN
      SET @c_hostwhcodeFilter = N' AND L.hostwhcode = @c_hostwhcode '
   END

   --WL01 S
   --SET @c_courierFilter = N''
   --IF ISNULL(@c_courier, '') <> ''
   --BEGIN
   --   IF UPPER(@c_courier) = 'ALL'
   --   BEGIN
   --      SET @c_courierFilter = N' AND OH.shipperkey in ('''',''SN'') '
   --   END
   --   ELSE IF UPPER(@c_courier) = 'JD'
   --   BEGIN
   --      SET @c_courierFilter = N' AND OH.shipperkey in ('''') '
   --   END
   --   ELSE IF UPPER(@c_courier) = 'SN'
   --   BEGIN
   --      SET @c_courierFilter = N' AND OH.shipperkey in (''SN'') '
   --   END
   --END
   SET @c_StoreFilter = N''

   IF ISNULL(@c_courier, '') <> ''
   BEGIN
      SELECT @c_StoreFilter = CASE @c_courier WHEN N'ALL' THEN ' AND OIF.StoreName <> '''' '
                                              WHEN N'TM'  THEN ' AND OIF.StoreName = ''618'' '
                                              WHEN N'GW'  THEN ' AND OIF.StoreName <> ''618'' '
                                              ELSE N' AND OIF.StoreName = ' + TRIM(@c_courier) END
   END
   --WL01 E

   SET @c_GrpByORD = N' Group By OH.storerkey,OD.Orderkey,OD.SKU,OH.Facility,OH.adddate'
   SET @c_GrpByLLISKU = N' Group by lli.storerkey,lli.sku,L.facility '
   SET @c_ORDERBYORD = N' ORDER BY OD.Orderkey'
   SET @c_ORDBY = N' ORDER BY OH.storerkey,OD.Orderkey,OD.SKU'

   SET @c_ExecMain = N''
   SET @c_ExecMain = N'       
   
   INSERT INTO #TMPORD (storerkey,orderkey,sku,Facility,OHADDDATE,ORIQTY,REPLEN)
   SELECT OH.storerkey,OD.Orderkey,OD.SKU,OH.Facility,OH.adddate,sum(OD.Originalqty),''''
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey
   LEFT JOIN ORDERINFO OIF WITH (NOLOCK) ON OH.Orderkey = OIF.Orderkey   /*WL01*/
   WHERE    OH.StorerKey = @c_storerkey    
            AND OH.facility  = @c_Facility  
   AND OH.Status=''0''  '


   IF @b_debug = 1
   BEGIN
      PRINT 'check insert   #TMPORD ' + ' @c_ExecMain ' + @c_ExecMain
   END

   SET @c_ExecStatements = @c_ExecMain + CHAR(13) + @c_OrderdateFilter + CHAR(13) + @c_StoreFilter + CHAR(13)   --WL01
                         + @c_GrpByORD + CHAR(13) + @c_ORDBY

   IF @b_debug = 1
   BEGIN
      PRINT @c_ExecStatements
   END

   SET @c_ExecArguments = N'@c_StorerKey NVARCHAR(15), @c_facility NVARCHAR(10),@c_StartOrderDate NVARCHAR(45), @c_EndOrderDate NVARCHAR(45)';
   EXEC sp_executesql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_storerkey
                    , @c_facility
                    , @c_StartOrderDate
                    , @c_EndOrderDate


   SET @c_ExecMain = N''
   SET @c_ExecStatements = N''

   SET @c_ExecMain = N'   
      insert into #TMPINV(storerkey,sku,Facility,AVAILQTY)
      select lli.storerkey,lli.sku,L.facility,sum(lli.Qty - lli.QtyAllocated - lli.QtyPicked)
      from LOTxLOCxID LLI WITH (NOLOCK)-- ON LLI.Storerkey = OD.Storerkey AND LLI.Sku = OD.Sku
      JOIN LOC L WITH (NOLOCK)  ON L.loc = LLI.LOC
      where lli.Storerkey = @c_storerkey 
      and L.facility = @c_Facility
      and L.LocationType = ''PICK''  
      and (lli.Qty - lli.QtyAllocated - lli.QtyPicked) > 0  
      and lli.sku in (select sku from #TMPORD) '

   SET @c_ExecStatements = @c_ExecMain + CHAR(13) + @c_hostwhcodeFilter + CHAR(13) + @c_GrpByLLISKU

   IF @b_debug = 1
   BEGIN
      PRINT @c_ExecStatements
   END


   SET @c_ExecArguments = N'@c_StorerKey NVARCHAR(15), @c_facility NVARCHAR(10),@c_hostwhcode NVARCHAR(20)';
   EXEC sp_executesql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_storerkey
                    , @c_facility
                    , @c_hostwhcode

   INSERT INTO #TMPORDTBL (Storerkey, Orderkey, SKU, Facility, ORIQTY, INVQTY, AVLQTY, CANREPLEN)
   SELECT TR.Storerkey AS storerkey
        , TR.Orderkey
        , TR.SKU
        , TR.Facility
        , TR.ORIQTY
        , TIV.AVAILQTY AS INVQTY
        , (TIV.AVAILQTY - TR.ORIQTY) AS AVLQTY
        , CASE WHEN (TIV.AVAILQTY - TR.ORIQTY) >= 1 THEN 'Y'
               ELSE 'N' END AS CANREPLEN
   FROM #TMPORD TR
   JOIN #TMPINV TIV ON TIV.sku = TR.SKU AND TIV.Storerkey = TR.Storerkey AND TIV.Facility = TR.Facility
   ORDER BY TR.Orderkey
          , TR.SKU

   INSERT INTO #TMPORDTBL1 (Storerkey, Orderkey, Facility)
   SELECT DISTINCT Storerkey AS storerkey
                 , Orderkey AS orderkey
                 , Facility AS facility
   FROM #TMPORDTBL
   GROUP BY Storerkey
          , Orderkey
          , Facility
   HAVING COUNT(DISTINCT CANREPLEN) = 1

   SET @n_AvaiQty = 0
   SET @c_replen = N''

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TR.Storerkey
        , TR.Orderkey
        , TR.SKU
        , TR.Facility
        , TR.ORIQTY
        , TIV.AVAILQTY AS INVQTY
        , (TIV.AVAILQTY - TR.ORIQTY) AS AVLQTY
   FROM #TMPORD TR
   JOIN #TMPINV TIV ON TIV.sku = TR.SKU AND TIV.Storerkey = TR.Storerkey AND TIV.Facility = TR.Facility
   JOIN #TMPORDTBL1 TBL1 ON  TBL1.Orderkey = TR.Orderkey
                         AND TBL1.Facility = TR.Facility
                         AND TBL1.Storerkey = TR.Storerkey
   -- WHERE REPLEN = ''
   ORDER BY TR.RowID


   OPEN CUR_RESULT

   FETCH NEXT FROM CUR_RESULT
   INTO @c_GetStorerKey
      , @c_getOrderkey
      , @c_getsku
      , @c_getfacility
      , @n_ORIQTY
      , @n_INVQTY
      , @n_AVLQTY

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @c_replen = N''
      SET @n_AllocQty = 0
      SET @n_getAvlqty = 0

      SELECT @c_replen = REPLEN
      FROM #TMPORD
      WHERE Storerkey = @c_GetStorerKey AND SKU = @c_getsku AND Facility = @c_getfacility AND Orderkey = @c_getOrderkey

      SELECT @n_getAvlqty = ISNULL(SUM(ORIQTY), 0)
      FROM #TMPORD
      WHERE Storerkey = @c_GetStorerKey AND SKU = @c_getsku AND Facility = @c_getfacility AND REPLEN = 'Y'

      SET @n_AVLQTY = (@n_INVQTY - @n_getAvlqty)
      --    select 'b4',@n_AvaiQty '@n_AvaiQty',@n_ORIQTY '@n_ORIQTY',@c_getOrderkey '@c_getOrderkey',@c_replen '@c_replen'
      IF @n_AVLQTY > 0 AND (@n_ORIQTY <= @n_AVLQTY) -- AND (@n_Avlqty - @n_AllocQty) >= @n_ORIQTY --AND ( @c_replen = ''  OR @c_replen <> 'N')
      BEGIN
         IF (@c_replen = '' OR @c_replen <> 'N')
         BEGIN
            UPDATE #TMPORD
            SET REPLEN = 'Y'
            WHERE Orderkey = @c_getOrderkey AND SKU = @c_getsku

         END

      END
      ELSE
      BEGIN
         UPDATE #TMPORD
         SET REPLEN = 'N'
         -- ,AllocatedQty = 0
         WHERE Orderkey = @c_getOrderkey
      END

      FETCH NEXT FROM CUR_RESULT
      INTO @c_GetStorerKey
         , @c_getOrderkey
         , @c_getsku
         , @c_getfacility
         , @n_ORIQTY
         , @n_INVQTY
         , @n_AVLQTY
   END
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT

   --select 'B4_#TMPORD',* from #TMPORD

   DECLARE CUR_CHKTMPORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
                 , Orderkey
   FROM #TMPORD
   WHERE REPLEN = 'N' OR REPLEN = ''
   ORDER BY Orderkey
   OPEN CUR_CHKTMPORD;

   FETCH NEXT FROM CUR_CHKTMPORD
   INTO @c_GetStorerKey
      , @c_getOrderkey

   WHILE @@FETCH_STATUS <> -1 --AND @n_Continue IN ( 1, 2 )  
   BEGIN

      UPDATE #TMPORD
      SET REPLEN = 'N'
      WHERE Storerkey = @c_GetStorerKey AND Orderkey = @c_getOrderkey

      FETCH NEXT FROM CUR_CHKTMPORD
      INTO @c_GetStorerKey
         , @c_getOrderkey
   END;

   CLOSE CUR_CHKTMPORD;
   DEALLOCATE CUR_CHKTMPORD;

   --select '#TMPORD',* from #TMPORD
   ----------------------Update Order Info    

   DECLARE CUR_UPDATEOIF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Storerkey
        , Orderkey
        , SKU
        , Facility
        , ORIQTY
   FROM #TMPORD
   WHERE REPLEN = 'Y'
   ORDER BY RowID

   OPEN CUR_UPDATEOIF;

   FETCH NEXT FROM CUR_UPDATEOIF
   INTO @c_GetStorerKey
      , @c_getOrderkey
      , @c_getsku
      , @c_getfacility
      , @n_ORIQTY

   WHILE @@FETCH_STATUS <> -1 --AND @n_Continue IN ( 1, 2 )  
   BEGIN
      BEGIN TRAN
      UPDATE OrderInfo WITH (ROWLOCK)
      SET DeliveryMode = 'NoReplen'
        , TrafficCop = NULL
        , EditDate = GETDATE()
        , EditWho = SUSER_SNAME()
      WHERE OrderKey = @c_getOrderkey

      SELECT @c_ErrorMsg = @@ERROR;
      IF @c_ErrorMsg <> 0
      BEGIN
         --SELECT @n_Continue = 3;  
         --SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
         --       @n_Err = 63330;  
         SELECT @c_ErrorMsg = N' Update Ordersinfo Failed! for Orderkey : ' + @c_getOrderkey
         ROLLBACK TRAN
         GOTO QUIT_SP

      END
      ELSE
      BEGIN
         COMMIT TRAN

         INSERT INTO #TMPORDERUP (Storerkey, Facility, ORDERKEY, sku, ORIQTY, AVAILQTY, OrdStartDate, OrderEndDate
                                , hostwhcode, courier, ErrMsg)
         VALUES (@c_storerkey, @c_facility, @c_getOrderkey, @c_getsku, @n_ORIQTY, 0
               , CAST(@c_StartOrderDate AS DATETIME), CAST(@c_EndOrderDate AS DATETIME), ISNULL(@c_hostwhcode, '')
               , ISNULL(@c_courier, ''), @c_ErrorMsg)
      END

      IF @b_debug = 1
      BEGIN
         PRINT @c_getOrderkey;
      END;

      FETCH NEXT FROM CUR_UPDATEOIF
      INTO @c_GetStorerKey
         , @c_getOrderkey
         , @c_getsku
         , @c_getfacility
         , @n_ORIQTY
   END;

   CLOSE CUR_UPDATEOIF;
   DEALLOCATE CUR_UPDATEOIF;
   --END
   QUIT_SP:

   IF ISNULL(@c_ErrorMsg, '') <> '' AND NOT EXISTS (  SELECT 1
                                                      FROM #TMPORDERUP
                                                      WHERE Storerkey = @c_storerkey AND @c_facility = @c_facility)
   BEGIN
      INSERT INTO #TMPORDERUP (Storerkey, Facility, ORDERKEY, sku, ORIQTY, AVAILQTY, OrdStartDate, OrderEndDate
                             , hostwhcode, courier, ErrMsg)
      VALUES (@c_storerkey, @c_facility, '', '', 0, 0, CAST(@c_StartOrderDate AS DATETIME)
            , CAST(@c_EndOrderDate AS DATETIME), ISNULL(@c_hostwhcode, ''), ISNULL(@c_courier, ''), @c_ErrorMsg)

   END

   SELECT *
   FROM #TMPORDERUP

   --WL01 S
   IF OBJECT_ID('tempdb..#TMPORD') IS NOT NULL
      DROP TABLE #TMPORD

   IF OBJECT_ID('tempdb..#TMPINV') IS NOT NULL
      DROP TABLE #TMPINV

   IF OBJECT_ID('tempdb..#TMPORDERUP') IS NOT NULL
      DROP TABLE #TMPORDERUP

   IF OBJECT_ID('tempdb..#TMPORDTBL') IS NOT NULL
      DROP TABLE #TMPORDTBL

   IF OBJECT_ID('tempdb..#TMPORDTBL1') IS NOT NULL
      DROP TABLE #TMPORDTBL1
   --WL01 E

END

GO