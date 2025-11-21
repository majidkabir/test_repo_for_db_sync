SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_BackendOrderGroupRelease                          */
/* Creation Date: 05-Aug-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:  WLChooi                                                    */
/*                                                                         */
/* Purpose: WMS-17637 - CN Pandora Backend Job for 2P order Notification CR*/
/*                                                                         */
/* Called By: SQL Job                                                      */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[isp_BackendOrderGroupRelease]  
(     @c_Storerkey   NVARCHAR(15)  = ''
  ,   @c_Facility    NVARCHAR(5)   = ''
  ,   @b_Success     INT           = 1  OUTPUT
  ,   @n_Err         INT           = 0  OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) = '' OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT = 0
         , @n_Continue           INT 
         , @n_StartTCnt          INT 

   DECLARE @c_MaxSameSKU      NVARCHAR(20)
         , @c_Orderkey        NVARCHAR(10)
         , @n_SKUCnt          INT

   DECLARE @c_Code           NVARCHAR(100) = ''
         , @c_Short          NVARCHAR(100) = ''
         , @c_UDF01          NVARCHAR(100) = ''
         , @n_RowCount       INT = 0

   DECLARE @c_SQL          NVARCHAR(4000) = ''
         , @c_SQLParm      NVARCHAR(4000) = ''
         , @c_FilterField  NVARCHAR(4000) = ''
         , @c_FilterValue  NVARCHAR(4000) = ''
         , @n_OpenQty      INT = 0
         , @c_ColType      NVARCHAR(20)   = ''

   IF @n_Err > 0
   BEGIN
      SET @b_Debug = @n_Err
   END
       
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   IF @n_continue = 1 or @n_continue = 2
   BEGIN 
      IF OBJECT_ID('#TMP_ORDERS_WIP') IS NOT NULL
      BEGIN 
         DROP TABLE #TMP_ORDERS_WIP
      END

      CREATE TABLE #TMP_ORDERS_WIP
      (    
         [Orderkey]        [nvarchar](10)    NOT NULL 
      )   

      CREATE INDEX IDX_SKUWIP1 ON #TMP_ORDERS_WIP (Orderkey) 

      CREATE TABLE #TMP_SKU
      (    
         [SKU]             [nvarchar](20)    NOT NULL 
      ) 
   END

   DECLARE CUR_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ISNULL(CL.Storerkey,''), ISNULL(CL.code2,'')
                    , TRIM(ISNULL(CL.UDF01,''))
                    , CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT) ELSE 0 END
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'ORDGROUP'
      AND CL.Storerkey = CASE WHEN ISNULL(@c_Storerkey,'') = '' THEN CL.Storerkey ELSE @c_Storerkey END
      AND CL.code2     = CASE WHEN ISNULL(@c_Facility,'')  = '' THEN CL.code2     ELSE @c_Facility END
      AND CL.Long = 'Y'   --A switch to enable/disable to run the job
   
   OPEN CUR_Loop
      
   FETCH NEXT FROM CUR_Loop INTO @c_Storerkey, @c_Facility, @c_FilterField, @n_OpenQty
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF ISNULL(@c_FilterField,'') = ''
      BEGIN
         SET @n_continue = 3      
         SET @n_err = 71800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': CODELKUP.UDF01 is Blank. (isp_BackendOrderGroupRelease)' + 
                         ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
         GOTO QUIT_SP
      END

      SELECT @c_ColType = DATA_TYPE
      FROM   INFORMATION_SCHEMA.COLUMNS
      WHERE  TABLE_NAME = 'ORDERS'
      AND    COLUMN_NAME = @c_FilterField

      IF ISNULL(@c_ColType,'') = '' OR @c_ColType <> 'NVARCHAR'   --Only allow update to nvarchar column
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 71805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': ' + TRIM(@c_FilterField) + ' is not in ORDERS table OR the column is not a NVARCHAR column. (isp_BackendOrderGroupRelease)' + 
                         ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
         GOTO QUIT_SP
      END 

NEXT_SKU:
      SET @c_SQL = 'SELECT TOP 1 @c_MaxSameSKU = OD.SKU
                               , @n_SKUCnt     = COUNT(1) 
                    FROM ORDERS OH (NOLOCK)
                    JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
                    JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.Sku
                    JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey 
                    WHERE OH.Storerkey = @c_Storerkey 
                    AND OH.[Status] = ''0''
                    AND OH.Openqty = @n_OpenQty 
                    AND OD.Originalqty = 1 
                    AND OH.Doctype = ''E'' 
                    AND (OH.Loadkey IS NULL OR OH.Loadkey = '''')
                    AND OH.Facility = CASE WHEN ISNULL(@c_Facility,'''') = '''' THEN OH.Facility ELSE @c_Facility END
                    AND OD.SKU NOT IN (SELECT DISTINCT SKU FROM #TMP_SKU)
                    AND P.Casecnt > 0
                    GROUP BY OD.SKU 
                    ORDER BY 2 DESC'

      SET @c_SQLParm =  N'  @c_Storerkey    NVARCHAR(15) ' +
                         ', @c_Facility     NVARCHAR(5)  ' +
                         ', @n_OpenQty      INT ' +
                         ', @c_MaxSameSKU   NVARCHAR(20) OUTPUT ' +
                         ', @n_SKUCnt       INT OUTPUT '

      EXEC sp_ExecuteSQL @c_SQL
                       , @c_SQLParm
                       , @c_Storerkey
                       , @c_Facility 
                       , @n_OpenQty
                       , @c_MaxSameSKU OUTPUT
                       , @n_SKUCnt     OUTPUT
      
      IF @b_Debug = 1
         SELECT @c_MaxSameSKU AS MaxSameSKU

      SET @c_SQL = N'INSERT INTO #TMP_ORDERS_WIP (Orderkey)
                     SELECT DISTINCT OD.OrderKey
                     FROM ORDERS OH (NOLOCK)
                     JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
                     JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.Sku
                     JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey
                     WHERE OD.StorerKey = @c_Storerkey
                     AND OH.[Status] = ''0''
                     AND OH.OpenQty = @n_OpenQty
                     AND OD.OriginalQty = 1
                     AND OH.DocType = ''E''
                     AND OH.Facility = CASE WHEN ISNULL(@c_Facility,'''') = '''' THEN OH.Facility ELSE @c_Facility END
                     AND P.CaseCnt > 0
                     AND (OH.Loadkey IS NULL OR OH.Loadkey = '''')
                     AND OD.SKU = @c_MaxSameSKU
                     AND OH.' + @c_FilterField + ' <> ''G'' '

      SET @c_SQLParm =  N'  @c_Storerkey    NVARCHAR(15) ' +
                         ', @c_Facility     NVARCHAR(5)  ' +
                         ', @n_OpenQty      INT ' +
                         ', @c_MaxSameSKU   NVARCHAR(20) '

      EXEC sp_ExecuteSQL @c_SQL
                       , @c_SQLParm
                       , @c_Storerkey
                       , @c_Facility
                       , @n_OpenQty
                       , @c_MaxSameSKU

      IF @b_Debug = 1
         SELECT DISTINCT SW.OrderKey
         FROM #TMP_ORDERS_WIP SW

      DECLARE CUR_UpdateOrd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT SW.OrderKey
         FROM #TMP_ORDERS_WIP SW

      OPEN CUR_UpdateOrd
      
      FETCH NEXT FROM CUR_UpdateOrd INTO @c_Orderkey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF EXISTS (SELECT 1 
                    FROM ORDERDETAIL OD (NOLOCK)
                    JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.Sku
                    LEFT JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey
                    WHERE (P.CaseCnt IS NULL OR P.CaseCnt <= 0) 
                    AND OD.OrderKey = @c_Orderkey)
         BEGIN 
            GOTO NEXT_UPD_ORDER
         END

         IF NOT EXISTS (SELECT 1
                        FROM ORDERDETAIL OD (NOLOCK)
                        WHERE OD.OrderKey = @c_Orderkey
                        HAVING COUNT(DISTINCT OD.SKU) >= 2)
         BEGIN
            GOTO NEXT_UPD_ORDER
         END

         SET @c_SQL = N'UPDATE ORDERS WITH (ROWLOCK)
                        SET TrafficCop =  NULL,
                            EditDate = GETDATE(),
                            EditWho = SUSER_SNAME(), ' +
                            @c_FilterField + ' = ''G'' 
                     	WHERE OrderKey = @c_Orderkey '
            
         SET @c_SQLParm =  N'@c_Orderkey    NVARCHAR(10) '

         EXEC sp_ExecuteSQL @c_SQL
                          , @c_SQLParm
                          , @c_Orderkey

         SELECT @n_Err = @@ERROR

         IF @n_Err <> 0      
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 71800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update ORDERS table field - Orderkey# ' + @c_Orderkey + '. (isp_BackendOrderGroupRelease)' + 
                            ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
            GOTO QUIT_SP  
         END

         SET @n_RowCount = @n_RowCount + 1
         
NEXT_UPD_ORDER:
         FETCH NEXT FROM CUR_UpdateOrd INTO @c_Orderkey
      END 
      CLOSE CUR_UpdateOrd
      DEALLOCATE CUR_UpdateOrd

      --If current MaxSameSKU did not mark > 0 orders, check next MaxSameSKU
      IF @n_RowCount = 0
      BEGIN
         INSERT INTO #TMP_SKU(SKU)
         SELECT @c_MaxSameSKU

         GOTO NEXT_SKU
      END

      FETCH NEXT FROM CUR_Loop INTO @c_Storerkey, @c_Facility, @c_FilterField, @n_OpenQty
   END
   CLOSE CUR_Loop
   DEALLOCATE CUR_Loop

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_Loop') IN (0 , 1)
   BEGIN
      CLOSE CUR_Loop
      DEALLOCATE CUR_Loop   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_MaxSameSKU') IN (0 , 1)
   BEGIN
      CLOSE CUR_MaxSameSKU
      DEALLOCATE CUR_MaxSameSKU   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_UpdateOrd') IN (0 , 1)
   BEGIN
      CLOSE CUR_UpdateOrd
      DEALLOCATE CUR_UpdateOrd   
   END

   IF OBJECT_ID('tempdb..#TMP_Orders') IS NOT NULL
      DROP TABLE #TMP_Orders

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_BackendOrderGroupRelease'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO