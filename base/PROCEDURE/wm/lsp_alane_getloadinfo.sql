SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_ALane_GetLoadInfo                               */                                                                                  
/* Creation Date: 2019-07-31                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1861- Assign Lane - SP  to get LoadplanDetails for     */
/*          Loadkey and  MBOLDetails for MBOLkey                        */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2021-02-05  mingle01 1.1  Add Big Outer Begin try/Catch             */ 
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_ALane_GetLoadInfo] 
      @c_Loadkey              NVARCHAR(10)   = ''                                                                                                                   
   ,  @c_MBOLkey              NVARCHAR(10)   = ''  
   ,  @c_AddFilterSQL         NVARCHAR(2000) = ''  --Addition SQL Filtering statement for eg. 'AND CustomerName = ''XXX'''   
   ,  @n_PageNo               INT            = 0
   ,  @n_NoOfRecPerPage       INT            = 0
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt         INT = @@TRANCOUNT  
         ,  @n_Continue          INT = 1

         ,  @n_RowId             INT = 0
         ,  @n_TotalCarton       INT = 0    
         ,  @n_TotalPallet       INT = 0    
         ,  @n_TotalLoose        INT = 0 
         ,  @n_NoOfLane          INT = 0   

         ,  @c_ExternOrderkey    NVARCHAR(50)   = ''
         ,  @c_Consigneekey      NVARCHAR(15)   = ''

         ,  @c_SQL               NVARCHAR(1000) = ''
         ,  @c_SQLParms          NVARCHAR(1000) = ''

   --(mingle01) - START
   BEGIN TRY
      IF OBJECT_ID (N'tempdb..#TMP_MASTER') IS NOT NULL 
      BEGIN
         DROP TABLE #TMP_MASTER 
      END

      CREATE TABLE #TMP_MASTER  
         (  RowID          INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  Loadkey        NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  MBOLKey        NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  ExternOrderkey NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Consigneekey   NVARCHAR(15)   NOT NULL DEFAULT('')
         ,  CustomerName   NVARCHAR(15)   NOT NULL DEFAULT('')
         )

      IF OBJECT_ID (N'tempdb..#TMP_LOAD') IS NOT NULL 
      BEGIN
         DROP TABLE #TMP_LOAD 
      END

      CREATE TABLE #TMP_LOAD 
         (  RowID          INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  Loadkey        NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  MBOLKey        NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  ExternOrderkey NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Consigneekey   NVARCHAR(15)   NOT NULL DEFAULT('')
         ,  CustomerName   NVARCHAR(15)   NOT NULL DEFAULT('')
         ,  TotalCarton    INT            NOT NULL DEFAULT(0)
         ,  TotalPallet    INT            NOT NULL DEFAULT(0)
         ,  TotalLoose     INT            NOT NULL DEFAULT(0) 
         ,  NoOfLane       INT            NOT NULL DEFAULT(0) 
         )

      SET @c_LoadKey = ISNULL(RTRIM(@c_LoadKey),'')
      SET @c_MBOLKey = ISNULL(RTRIM(@c_MBOLKey),'')

      IF (@c_LoadKey  = '' AND @c_MBOLKey  = '') OR
         (@c_LoadKey <> '' AND @c_MBOLKey <> '')
      BEGIN
         GOTO EXIT_SP
      END

      IF @n_PageNo = 0
      BEGIN
         GOTO EXIT_SP
      END 

      IF @n_NoOfRecPerPage = 0
      BEGIN
         GOTO EXIT_SP
      END 

      IF @c_LoadKey <> '' 
      BEGIN
         INSERT INTO #TMP_MASTER
            (  
               Loadkey
            ,  MBOLKey
            ,  ExternOrderkey
            ,  Consigneekey
            ,  CustomerName
            )  
         SELECT @c_Loadkey
            ,  @c_MBOLkey 
            ,  ExternOrderkey = ISNULL(LOADPLANDETAIL.ExternOrderkey,'')
            ,  Consigneekey   = ISNULL(LOADPLANDETAIL.Consigneekey,'')
            ,  CustomerName   = ISNULL(LOADPLANDETAIL.CustomerName,'')
         FROM LOADPLANDETAIL WITH (NOLOCK)
         WHERE Loadkey = @c_Loadkey          
      END
      ELSE
      BEGIN
         INSERT INTO #TMP_MASTER
            (  
               Loadkey
            ,  MBOLKey
            ,  ExternOrderkey
            ,  Consigneekey
            ,  CustomerName
            )  
         SELECT @c_Loadkey
            ,  @c_MBOLkey 
            ,  ExternOrderkey = ISNULL(MBOLDETAIL.ExternOrderkey,'')  
            ,  Consigneekey   = ISNULL(ORDERS.Consigneekey,'')  
            ,  CustomerName   = ISNULL(ORDERS.C_Company,'')  
         FROM MBOLDETAIL WITH (NOLOCK) 
         JOIN ORDERS WITH (NOLOCK) 
              ON MBOLDETAIL.Orderkey = ORDERS.Orderkey   
         WHERE MBOLDETAIL.MBOLKey = @c_MBOLkey 
      END

      SET @c_SQL = N'SELECT Loadkey'
               + ', MBOLkey'
               + ', ExternOrderkey'
               + ', Consigneekey'
               + ', CustomerName'
               + ' FROM #TMP_MASTER WITH (NOLOCK)'
               + ' WHERE RowID > 0'
               + ' ' + @c_AddFilterSQL
               + ' ORDER BY ExternOrderkey' 
               + ' OffSet ( @n_PageNo - 1 ) * @n_NoOfRecPerPage ROWS FETCH NEXT @n_NoOfRecPerPage ROWS ONLY'

      SET @c_SQLParms= N'@n_PageNo           INT'
                     + ',@n_NoOfRecPerPage   INT'   

      INSERT INTO #TMP_LOAD
         (  
            Loadkey
         ,  MBOLKey
         ,  ExternOrderkey
         ,  Consigneekey
         ,  CustomerName
         )

      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@n_PageNo
                        ,@n_NoOfRecPerPage
  
      SET @n_RowID = 0
      WHILE 1 = 1
      BEGIN 
         SELECT TOP 1 
               @n_RowID = RowID
            ,  @c_Loadkey = Loadkey
            ,  @c_MBOLKey = MBOLKey
            ,  @c_ExternOrderkey = ExternOrderkey
            ,  @c_Consigneekey = Consigneekey
         FROM #TMP_LOAD
         WHERE RowID > @n_RowID
         ORDER BY RowID

         IF @@ROWCOUNT = 0 
         BEGIN
            BREAK
         END          

         IF @c_Loadkey <> ''
         BEGIN   
            SELECT @n_NoOfLane = COUNT(DISTINCT Loc)
            FROM LOADPLANLANEDETAIL LPL (NOLOCK)
            WHERE Loadkey      = @c_Loadkey
            AND Externorderkey = @c_externorderkey
            AND Consigneekey   = @c_consigneekey

            EXEC isp_GetPPKPltCase 
                     @c_Loadkey        = @c_Loadkey
                  ,  @c_externorderkey = @c_externorderkey
                  ,  @c_consigneekey   = @c_consigneekey
                  ,  @n_totalcarton    = @n_totalcarton  OUTPUT
                  ,  @n_totalpallet    = @n_totalpallet  OUTPUT
                  ,  @n_totalloose     = @n_totalloose   OUTPUT
         END
         ELSE
         BEGIN
            SELECT @n_NoOfLane = COUNT(DISTINCT Loc)
            FROM LOADPLANLANEDETAIL LPL (NOLOCK)
            WHERE MBOLKey      = @c_MBOLKey
            AND Externorderkey = @c_externorderkey
            AND Consigneekey   = @c_consigneekey

            EXEC isp_GetPPKPltCase_MBOL 
                  @c_MBOLkey        = @c_MBOLKey
               ,  @c_externorderkey = @c_externorderkey
               ,  @c_consigneekey   = @c_consigneekey
               ,  @n_totalcarton    = @n_totalcarton  OUTPUT
               ,  @n_totalpallet    = @n_totalpallet  OUTPUT
               ,  @n_totalloose     = @n_totalloose   OUTPUT
         END

         UPDATE #TMP_LOAD
            SET TotalCarton = ISNULL(@n_TotalCarton,0)
               ,TotalPallet = ISNULL(@n_TotalPallet,0)
               ,TotalLoose  = ISNULL(@n_TotalLoose,0) 
               ,NoOfLane    = @n_NoOfLane
         WHERE RowID = @n_RowID
      END      
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      TRUNCATE TABLE #TMP_LOAD
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:
   IF @c_Loadkey <> ''
   BEGIN
      SELECT Loadkey
            ,ExternOrderkey
            ,Consigneekey
            ,CustomerName
            ,TotalCarton
            ,TotalPallet
            ,TotalLoose
            ,NoOfLane
      FROM #TMP_LOAD
   END
   ELSE
   BEGIN
      SELECT MBOLKey
            ,ExternOrderkey  
            ,Consigneekey
            ,CustomerName
            ,TotalCarton
            ,TotalPallet
            ,TotalLoose
            ,NoOfLane
      FROM #TMP_LOAD
   END 
END

GO