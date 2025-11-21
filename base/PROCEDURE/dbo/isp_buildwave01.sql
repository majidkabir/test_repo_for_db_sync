SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_BuildWave01                                             */
/* Creation Date: 24-MAR-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22092 CN Converse Build Wave order filtering by pickzone*/
/*        :                                                             */
/* Called By: WM.lsp_Build_Wave. By stored proc condition               */          
/*          : isp_BuildWave01 @c_Parm1='CROSS'                          */
/*          : if apply for build load need to add @c_Parm2 = 'LOAD'     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE   PROC [dbo].[isp_BuildWave01] 
            @c_Facility           NVARCHAR(5)
         ,  @c_Storerkey          NVARCHAR(15)
         ,  @c_ParmCode           NVARCHAR(10)
         ,  @c_ParmCodeCond       NVARCHAR(4000)
         ,  @c_BuildWaveType      NVARCHAR(30) = '' --DEFAULT BLANK = BuildWave, Analysis, PreWave & etc
         ,  @c_Parm01             NVARCHAR(50) = '' --CROSS, ONLY1, ONLY8
         ,  @c_Parm02             NVARCHAR(50) = '' --DEFAULT BLANK = WAVE, LOAD
         ,  @c_Parm03             NVARCHAR(50) = ''
         ,  @c_Parm04             NVARCHAR(50) = ''
         ,  @c_Parm05             NVARCHAR(50) = ''
         ,  @dt_StartDate         DATETIME     = NULL  
         ,  @dt_EndDate           DATETIME     = NULL  
         ,  @n_NoOfOrderToRelease INT          = 0     
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @b_Success         INT 
         , @n_err             INT 
         , @c_errmsg          NVARCHAR(255)  
         , @c_SQL             NVARCHAR(MAX)
         , @b_JoinPickDetail  BIT = 0 
         , @b_JoinLoc         BIT = 0           
         , @b_JoinOrderInfo   BIT = 0
         , @b_Debug           BIT
                     
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @b_Success  = 1

   SET @b_Debug = 0
   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NULL
   BEGIN
      CREATE TABLE #TMP_ORDERS
      (  RowNo       BIGINT   IDENTITY(1,1)  Primary Key 
      ,  Orderkey    NVARCHAR(10)   NULL
      )
      SET @b_Debug = 1
   END

   IF CHARINDEX('PICKDETAIL.', @c_ParmCodeCond) > 1
   BEGIN
     SET @b_JoinPickDetail = 1
   END

   IF CHARINDEX('LOC.', @c_ParmCodeCond) > 1
   BEGIN
     SET @b_JoinLoc = 1
   END
   
   IF CHARINDEX('ORDERINFO.', @c_ParmCodeCond) > 1
   BEGIN
     SET @b_JoinOrderInfo = 1
   END
           
   IF CHARINDEX('FROM', @c_ParmCodeCond) > 0
   BEGIN
      IF CHARINDEX('WHERE', @c_ParmCodeCond) > 0
      BEGIN
      	  SET @c_ParmCodeCond = ' AND ' + SUBSTRING(@c_ParmCodeCond, CHARINDEX('WHERE', @c_ParmCodeCond) + 5, LEN(@c_ParmCodeCond))
      END
   END
   
   IF ISNULL(@c_Parm01,'') NOT IN('CROSS','ONLY1','ONLY8')
      SET @c_Parm01 = 'CROSS'

   SET @b_JoinLoc = 1
   SET @c_SQL = N'INSERT INTO #TMP_ORDERS (Orderkey) '               
             + ' SELECT ORDERS.Orderkey '
             + ' FROM ORDERS WITH (NOLOCK)'
             + ' JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)'
             + ' JOIN SKU  WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)'
             +                         ' AND(ORDERDETAIL.Sku = SKU.Sku)'
             + ' JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)'
             + CASE WHEN @b_JoinLoc = 1 OR @b_JoinPickDetail = 1
                    THEN ' JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey=PICKDETAIL.Orderkey) AND (ORDERDETAIL.OrderLineNumber=PICKDETAIL.OrderLineNumber)'
                    ELSE '' END
             + CASE WHEN @b_JoinLoc = 1 
                    THEN ' LEFT JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc=LOC.Loc AND LOC.Facility = @c_Facility)' 
                    ELSE '' END
             + CASE WHEN @c_Parm02 = 'LOAD' 
                    THEN ' LEFT JOIN LOADPLANDETAIL LD (NOLOCK) ON LD.OrderKey = ORDERS.OrderKey'  
                    ELSE ' LEFT JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = ORDERS.OrderKey' END
             + CASE WHEN @b_JoinOrderInfo = 1 
                    THEN ' LEFT JOIN OrderInfo WITH(NOLOCK) ON OrderInfo.OrderKey = ORDERS.OrderKey'             
                    ELSE '' END
             + ' WHERE ORDERS.Facility  = @c_Facility'
             + ' AND   ORDERS.Storerkey = @c_Storerkey'
             + ' AND   ORDERS.Status < ''9'''
             + CASE WHEN @c_Parm02 = 'LOAD' 
                    THEN ' AND  (ORDERS.Loadkey IS NULL OR ORDERS.Loadkey = '''')'
                    ELSE ' AND  (ORDERS.UserDefine09 = '''' OR ORDERS.UserDefine09 IS NULL)' END
             + ' AND ORDERS.SOStatus <> ''PENDING'' '  
             + ' AND NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) '  
             + '                 WHERE CODELKUP.Code = ORDERS.SOStatus ' 
             + '                 AND CODELKUP.Listname = ''LBEXCSOSTS'' '
             + '                 AND CODELKUP.Storerkey = ORDERS.Storerkey) '  
             + CASE WHEN @c_Parm02 = 'LOAD' 
                    THEN ' AND ((ORDERS.UserDefine08 = ''N'' AND ( ORDERS.UserDefine09 = '''' OR ORDERS.UserDefine09 is NULL) AND (ORDERS.Status < ''8'') ) OR 
                           (ORDERS.UserDefine08 = ''Y'' AND ORDERS.UserDefine09 <> '''' AND (ORDERS.Status >= ''1'' AND ORDERS.Status < ''8'' ) )) '
                    ELSE ' ' END      
             + RTRIM(ISNULL(@c_ParmCodeCond,''))
             + ' GROUP BY ORDERS.Orderkey '                           
             + CASE WHEN @c_Parm01 = 'CROSS' THEN
                    ' HAVING SUM(CASE WHEN LEFT(LOC.PickZone,1)=''1'' THEN 1 ELSE 0 END) > 0 AND SUM(CASE WHEN LEFT(LOC.PickZone,1)=''8'' THEN 1 ELSE 0 END) > 0 '
                    WHEN @c_Parm01 = 'ONLY1' THEN
                    ' HAVING SUM(CASE WHEN LEFT(LOC.PickZone,1)=''1'' THEN 1 ELSE 0 END) > 0 AND SUM(CASE WHEN LEFT(LOC.PickZone,1)=''8'' THEN 1 ELSE 0 END) = 0 '
                    WHEN @c_Parm01 = 'ONLY8' THEN
                    ' HAVING SUM(CASE WHEN LEFT(LOC.PickZone,1)=''1'' THEN 1 ELSE 0 END) = 0 AND SUM(CASE WHEN LEFT(LOC.PickZone,1)=''8'' THEN 1 ELSE 0 END) > 0 ' 
               ELSE '' END
              
   EXEC sp_executesql @c_SQL
           , N'@c_Facility NVARCHAR(5), @c_Storerkey NVARCHAR(15), @dt_StartDate DATETIME, @dt_EndDate DATETIME'
           , @c_Facility
           , @c_Storerkey
           , @dt_StartDate
           , @dt_EndDate              
                            
QUIT_SP:

   IF @b_Debug = 1
   BEGIN
      SELECT Orderkey
      FROM #TMP_ORDERS
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BuildWave01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO