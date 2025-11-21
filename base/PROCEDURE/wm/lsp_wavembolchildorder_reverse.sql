SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveMBOLChildOrder_Reverse                      */                                                                                  
/* Creation Date: 2019-04-29                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( MBOL reverse Create Child Order To MBOL )               */
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
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveMBOLChildOrder_Reverse] 
      @c_WaveKey              NVARCHAR(10)                                                                                                                    
   ,  @c_MBOLkey              NVARCHAR(10)   
   ,  @c_OrderkeyList         NVARCHAR(4000) --Seperator by |          
   ,  @c_CaseIDList           NVARCHAR(4000) --Seperator by |        
   ,  @b_Success              INT = 1                 OUTPUT  
   ,  @n_err                  INT = 0                 OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= ''       OUTPUT 
   ,  @n_WarningNo            INT          = 0        OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                     
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         
   ,  @n_ErrGroupKey          INT          = 0        OUTPUT
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1
         
         ,  @c_TableName                  NVARCHAR(50)   = 'MBOLDETAIL'
         ,  @c_SourceType                 NVARCHAR(50)   = 'lsp_WaveMBOLChildOrder_Reverse'

         ,  @c_CaseID                     NVARCHAR(20)   = ''
         ,  @c_Orderkey                   NVARCHAR(10)   = ''
         ,  @c_Store                      NVARCHAR(20)   = ''
         ,  @c_PExternOrderkey            NVARCHAR(30)   = ''

         ,  @CUR_CTN                      CURSOR

   DECLARE @T_ORDERS TABLE   
         (  RowRef      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  Orderkey    NVARCHAR(10)   NULL
         )

   DECLARE @T_CASEID TABLE   
         (  RowRef      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  CaseID      NVARCHAR(20)   NULL
         )

   DECLARE @T_CASEORDER TABLE   
         (  Orderkey          NVARCHAR(10)   NULL
         ,  Store             NVARCHAR(18)   NULL
         ,  PExternOrderkey   NVARCHAR(30) NULL
         ,  CaseID            NVARCHAR(20)   NULL
         )

   SET @b_Success = 1
   SET @n_Err     = 0
               
   SET @n_Err = 0 
   --(mingle01) - START   
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END
   --(mingle01) - END
   
   --(mingle01) - START
   BEGIN TRY
      SET @n_ErrGroupKey = 0

      SET @c_MBOLKey = ISNULL(@c_MBOLKey,'')

      INSERT INTO @T_ORDERS (Orderkey)
      SELECT [VALUE]
      FROM STRING_SPLIT ( @c_OrderkeyList , '|' )  

      INSERT INTO @T_CASEID (CaseID)
      SELECT [VALUE]
      FROM STRING_SPLIT ( @c_CaseIDList , '|' )  

      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         INSERT INTO @T_CASEORDER   
            (  Orderkey
            ,  Store
            ,  PExternOrderkey
            ,  CaseID
            )
         SELECT DISTINCT 
                  PD.Orderkey
               ,  Store = ISNULL(OH.Consigneekey,'')   
               ,  PExternOrderkey  = ISNULL(OHP.ExternOrderkey,'')              
               ,  CTN.CaseID
         FROM @T_CASEID CTN
         JOIN PICKDETAIL  PD WITH (NOLOCK) ON  CTN.CaseID = PD.CaseID
         JOIN ORDERS      OH WITH (NOLOCK) ON  OH.Orderkey = PD.Orderkey
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON  OD.Orderkey = PD.Orderkey
                                           AND OD.OrderLineNumber = PD.OrderLineNumber 
         JOIN ORDERS       OHP WITH (NOLOCK) ON  OHP.Orderkey= OD.UserDefine09
         JOIN DROPIDDETAIL DPD WITH (NOLOCK) ON  DPD.Childid = PD.CaseID 
                                             AND DPD.Userdefine01 = OD.Mbolkey 
         WHERE PD.ShipFlag <> 'Y' 
         AND   PD.[Status] < '9'
         AND ( OD.UserDefine09 <> '' AND OD.UserDefine09 IS NOT NULL )
         AND ( OD.UserDefine10 <> '' AND OD.UserDefine10 IS NOT NULL )

         SET @CUR_CTN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT T.CaseID
         FROM @T_CASEORDER T
         WHERE NOT EXISTS (SELECT 1 
                           FROM @T_ORDERS SO
                           JOIN @T_CASEID CTN ON SO.RowRef = CTN.RowRef
                           WHERE T.Orderkey = SO.Orderkey
                           AND   T.CaseID   = CTN.CaseID
                           )
         OPEN @CUR_CTN
      
         FETCH NEXT FROM @CUR_CTN INTO @c_CaseID                                                                              
                                       
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_Err = 556701
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Disallow Partial Child Order selected to reverse'
                          + '. Carton #: ' + @c_CaseID 
                          + '. (lsp_WaveMBOLChildOrder_Reverse) |' +  @c_CaseID 

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_WaveKey
               ,  @c_Refkey2     = @c_MBOLkey
               ,  @c_Refkey3     = @c_Orderkey
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT

            FETCH NEXT FROM @CUR_CTN INTO @c_CaseID   
         END
         CLOSE @CUR_CTN
         DEALLOCATE @CUR_CTN

         IF @n_ErrGroupKey > 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP
         END
      END

      SET @CUR_CTN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT T.Orderkey
         ,   T.Store
         ,   T.PExternOrderkey
         ,   T.CaseID
      FROM @T_CASEORDER T
      ORDER BY T.CaseID
            ,  T.Orderkey

      OPEN @CUR_CTN
      
      FETCH NEXT FROM @CUR_CTN INTO @c_Orderkey
                                 ,  @c_Store
                                 ,  @c_PExternOrderkey
                                 ,  @c_CaseID                                                                              
                                       
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRY

            EXEC [dbo].[isp_ChildOrder_Reverse]  
                 @c_MBOLkey         = @c_MBOLkey
               , @c_Orderkey        = @c_Orderkey
               , @c_Store           = @c_Store
               , @c_PExternOrderkey = @c_PExternOrderkey
               , @c_CaseID          = @c_CaseID
               , @b_Success         = @b_Success      OUTPUT
               , @n_Err             = @n_Err          OUTPUT 
               , @c_ErrMsg          = @c_ErrMsg       OUTPUT 
         END TRY

         BEGIN CATCH
            SET @n_Err = 556702
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_ChildOrder_Reverse. (lsp_WaveMBOLChildOrder_Reverse)'   
                           + '(' + @c_ErrMsg + ')' 
                       
            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_WaveKey
               ,  @c_Refkey2     = @c_MBOLkey
               ,  @c_Refkey3     = @c_Orderkey
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT

            IF (XACT_STATE()) = -1  
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END  
         END CATCH

         FETCH NEXT FROM @CUR_CTN INTO @c_Orderkey
                                    ,  @c_Store
                                    ,  @c_PExternOrderkey
                                    ,  @c_CaseID     
      END
      CLOSE @CUR_CTN
      DEALLOCATE @CUR_CTN
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:


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
      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveMBOLChildOrder_Reverse'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END      
   REVERT
END

GO