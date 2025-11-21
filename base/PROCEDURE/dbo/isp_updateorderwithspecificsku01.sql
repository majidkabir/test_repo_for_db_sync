SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_UpdateOrderWithSpecificSKU01                   */  
/* Creation Date: 24-Jun-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-17334 CN IKEA_Specify the SKU order report              */  
/*                                                                      */  
/* Called By: r_dw_updateorderwithspecificSKU01                         */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_UpdateOrderWithSpecificSKU01]   
     @c_Storerkey        NVARCHAR(15)  
   , @c_Facility         NVARCHAR(25)  
   , @b_debug            INT = 0
 
AS        
BEGIN       
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue          INT
         , @b_Success           INT
         , @n_Err               INT
         , @c_ErrMsg            NVARCHAR(250)
         , @n_StartTCnt         INT
   
   DECLARE @c_AllSKU            NVARCHAR(MAX)
         , @c_Orderkey          NVARCHAR(10)
         , @n_OrderFulfillCnt   INT
         , @c_CLShort           NVARCHAR(10)
         , @c_CLLong            NVARCHAR(250)
         , @c_CLNotes           NVARCHAR(4000)
         , @c_CLUDF01           NVARCHAR(60)
         , @c_CLUDF02           NVARCHAR(60)
         , @c_CLUDF03           NVARCHAR(60)
         , @c_CLUDF04           NVARCHAR(60)
         , @c_CLUDF05           NVARCHAR(60)
         , @n_TotalSKU          INT
         , @n_CurrOrdTotalSKU   INT
         , @c_BZip              NVARCHAR(255) = ''
         , @c_ColValue          NVARCHAR(100)
         , @c_ResultMsg         NVARCHAR(4000) = ''
         , @c_UpdateBZip        NVARCHAR(18) = ''

   SELECT @n_continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_StartTCnt = @@TRANCOUNT

   SET @n_OrderFulfillCnt = 0
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN 

   --Initialization
   IF @n_continue IN (1,2)
   BEGIN
      CREATE TABLE #TMP_ORDER (
            Orderkey   NVARCHAR(10)
      )

      CREATE NONCLUSTERED INDEX IDX_TMP_ORDER_01 ON #TMP_ORDER (Orderkey)

      CREATE TABLE #TMP_SKU (
            Storerkey NVARCHAR(15)
          , SKU       NVARCHAR(20)
      )

      CREATE NONCLUSTERED INDEX IDX_TMP_SKU_01 ON #TMP_SKU (Storerkey, SKU)

      CREATE TABLE #TMP_CODELKUP (
            Short    NVARCHAR(10)
          , Long     NVARCHAR(250)
          , Notes    NVARCHAR(4000)
          , UDF01    NVARCHAR(60)
          , UDF02    NVARCHAR(60)
          , UDF03    NVARCHAR(60)
          , UDF04    NVARCHAR(60)
          , UDF05    NVARCHAR(60)
      )

      CREATE TABLE #TMP_Result (
            B_Zip      NVARCHAR(100)
          , Orderkey   NVARCHAR(10)
      )

      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ISNULL(CL.Short,'0')
                    , ISNULL(CL.Long ,'A')
                    , ISNULL(CL.Notes,'')
                    , ISNULL(CL.UDF01,'')
                    , ISNULL(CL.UDF02,'')
                    , ISNULL(CL.UDF03,'')
                    , ISNULL(CL.UDF04,'')
                    , ISNULL(CL.UDF05,'')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'SKUOrd'
      AND CL.Storerkey = @c_Storerkey

      OPEN CUR_CODELKUP

      FETCH NEXT FROM CUR_CODELKUP INTO @c_CLShort
                                      , @c_CLLong 
                                      , @c_CLNotes
                                      , @c_CLUDF01
                                      , @c_CLUDF02
                                      , @c_CLUDF03
                                      , @c_CLUDF04
                                      , @c_CLUDF05

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @c_AllSKU = CASE WHEN ISNULL(@c_CLUDF01,'') = '' THEN '' ELSE LTRIM(RTRIM(@c_CLUDF01)) + ',' END
                          + CASE WHEN ISNULL(@c_CLUDF02,'') = '' THEN '' ELSE LTRIM(RTRIM(@c_CLUDF02)) + ',' END
                          + CASE WHEN ISNULL(@c_CLUDF03,'') = '' THEN '' ELSE LTRIM(RTRIM(@c_CLUDF03)) + ',' END
                          + CASE WHEN ISNULL(@c_CLUDF04,'') = '' THEN '' ELSE LTRIM(RTRIM(@c_CLUDF04)) + ',' END
                          + CASE WHEN ISNULL(@c_CLUDF05,'') = '' THEN '' ELSE LTRIM(RTRIM(@c_CLUDF05)) + ',' END
                          + CASE WHEN ISNULL(@c_CLNotes,'') = '' THEN '' ELSE LTRIM(RTRIM(@c_CLNotes)) END

         INSERT INTO #TMP_SKU (Storerkey, SKU)
         SELECT DISTINCT @c_Storerkey, LTRIM(RTRIM(ColValue)) 
         FROM dbo.fnc_DelimSplit(',', @c_AllSKU)
         WHERE ColValue <> ''

         IF NOT EXISTS (SELECT 1 FROM #TMP_SKU)
            GOTO NEXT_CODELKUP
         
         SELECT @n_TotalSKU = COUNT(DISTINCT SKU)
         FROM #TMP_SKU

         IF @c_BZip = ''
            SET @c_BZip = @c_CLLong
         ELSE
            SET @c_BZip = @c_BZip + ',' + @c_CLLong

         INSERT INTO #TMP_ORDER (Orderkey)
         SELECT OH.Orderkey
         FROM ORDERS OH (NOLOCK)
         WHERE OH.StorerKey = @c_Storerkey
         AND OH.Facility = @c_Facility
         AND OH.[Status] = @c_CLShort
         AND OH.B_Zip NOT IN (@c_CLLong)
         
         IF NOT EXISTS (SELECT 1 FROM #TMP_ORDER)
            GOTO NEXT_CODELKUP

         --For Debugging Only
         IF @b_debug = 1
         BEGIN
            SELECT @n_TotalSKU AS TotalSKUFromCodelkup
            SELECT * FROM #TMP_ORDER TOR
            SELECT * FROM #TMP_SKU TS
         END

         --Main Process
         IF @n_continue IN (1,2)
         BEGIN
            DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TOR.OrderKey
               FROM #TMP_ORDER TOR
         
            OPEN CUR_LOOP
         
            FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey
         
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SELECT @n_CurrOrdTotalSKU = COUNT(DISTINCT OD.SKU)
               FROM ORDERDETAIL OD (NOLOCK)
               JOIN #TMP_SKU TS ON TS.SKU = OD.SKU AND TS.Storerkey = OD.StorerKey
               WHERE OD.OrderKey = @c_Orderkey

               --Orderdetail Must Match all SKU with Codelkup.UDF01 + UDF02 + UDF03 + UDF04 + UDF05 + Notes then only can update B_Zip
               IF @n_CurrOrdTotalSKU <> @n_TotalSKU
               BEGIN
                  GOTO NEXT_LOOP
               END

               SELECT @n_CurrOrdTotalSKU = COUNT(DISTINCT OD.SKU)
               FROM ORDERDETAIL OD (NOLOCK)
               WHERE OD.OrderKey = @c_Orderkey

               --Compare Total OrderDetail SKU
               IF @n_CurrOrdTotalSKU <> @n_TotalSKU
               BEGIN
                  GOTO NEXT_LOOP
               END

               IF @b_debug = 2
               BEGIN
                  PRINT 'Orderkey# ' + @c_Orderkey + ', CurrOrdTotalSKU = ' + CAST(@n_CurrOrdTotalSKU AS NVARCHAR) + ', TotalSKU = ' + CAST(@n_TotalSKU AS NVARCHAR)
               END

               IF EXISTS (SELECT 1 FROM #TMP_Result TR WHERE TR.Orderkey = @c_Orderkey)
               BEGIN
                  UPDATE #TMP_Result
                  SET B_Zip = B_Zip + LEFT(TRIM(@c_CLLong), 18)
                  WHERE Orderkey = @c_Orderkey
               END
               ELSE
               BEGIN
                  INSERT INTO #TMP_Result(B_Zip, Orderkey)
                  SELECT LEFT(@c_CLLong, 18), @c_Orderkey
               END

               SELECT @c_UpdateBZip = B_Zip
               FROM #TMP_Result
               WHERE Orderkey = @c_Orderkey
         
               UPDATE ORDERS
               SET B_Zip      = @c_UpdateBZip
                 , TrafficCop = NULL
                 , EditDate   = GETDATE()
                 , EditWho    = SUSER_SNAME()
               WHERE OrderKey = @c_Orderkey
         
               SELECT @n_Err =  @@ERROR 
            	    
               IF @n_Err <> 0 
               BEGIN
                  SET @n_Continue = 3    
                  SET @n_Err = 63550    
                  SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Failed On Table ORDERS. (isp_UpdateOrderWithSpecificSKU01)'
               END
NEXT_LOOP:    
               --SET @n_OrderFulfillCnt = @n_OrderFulfillCnt + 1
         
               FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
         END

         TRUNCATE TABLE #TMP_ORDER
         TRUNCATE TABLE #TMP_SKU

NEXT_CODELKUP:
         FETCH NEXT FROM CUR_CODELKUP INTO @c_CLShort
                                         , @c_CLLong 
                                         , @c_CLNotes
                                         , @c_CLUDF01
                                         , @c_CLUDF02
                                         , @c_CLUDF03
                                         , @c_CLUDF04
                                         , @c_CLUDF05
      END
      CLOSE CUR_CODELKUP
      DEALLOCATE CUR_CODELKUP 
   END

   --For Debugging Only
   IF @b_debug = 1
   BEGIN
      SELECT * FROM #TMP_Result
   END

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT B_Zip 
   FROM #TMP_Result

   OPEN CUR_RESULT

   FETCH NEXT FROM CUR_RESULT INTO @c_ColValue

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_OrderFulfillCnt = 0

      SELECT @n_OrderFulfillCnt = COUNT(1)
      FROM #TMP_Result TR
      WHERE TR.B_Zip = @c_ColValue

      IF @c_ResultMsg = ''
         SET @c_ResultMsg = RTRIM(CAST(@n_OrderFulfillCnt AS NVARCHAR)) + ' orders are updated as ' + LTRIM(RTRIM(@c_ColValue)) + ' at ORDERS.B_ZIP.'
      ELSE 
         SET @c_ResultMsg = @c_ResultMsg + ' ' + RTRIM(CAST(@n_OrderFulfillCnt AS NVARCHAR)) + ' orders are updated as ' + LTRIM(RTRIM(@c_ColValue)) + ' at ORDERS.B_ZIP.'

      FETCH NEXT FROM CUR_RESULT INTO @c_ColValue
   END
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_ORDER') IS NOT NULL
      DROP TABLE #TMP_ORDER

   IF OBJECT_ID('tempdb..#TMP_SKU') IS NOT NULL
      DROP TABLE #TMP_SKU
   
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_CODELKUP') IN (0 , 1)
   BEGIN
      CLOSE CUR_CODELKUP
      DEALLOCATE CUR_CODELKUP   
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN         	 
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      SELECT 'Error: No order is updated.'
      UNION ALL
      SELECT @c_ErrMsg

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_UpdateOrderWithSpecificSKU01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      
      SELECT @c_ResultMsg    
   END      
END  

GO