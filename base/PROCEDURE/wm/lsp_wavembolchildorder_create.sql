SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveMBOLChildOrder_Create                       */                                                                                  
/* Creation Date: 2019-04-23                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( Create Child Order To MBOL )                            */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.2                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2022-01-05  Wan01    1.2   Fixed incorrect lsp_build_wave SP name in */
/*                            Error Message                             */
/* 2022-01-05  Wan01    1.2   DevOps Combine Script                     */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveMBOLChildOrder_Create] 
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
   
   ---------------------------------------------------------------------------------------------------------------
   -- 1) Parent Orderkey POPulate Screen Get Parent Order From Orders Table. Parent Order should not Build to Wave
   -- 2) Create New MBOL Key for first Child Order (Same Consigneekey and Caseid). 
   -- 3) Child Orderkey to create for the wave.
   ---------------------------------------------------------------------------------------------------------------    

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1
         
         ,  @c_TableName                  NVARCHAR(50)   = 'MBOLDETAIL'
         ,  @c_SourceType                 NVARCHAR(50)   = 'lsp_WaveMBOLChildOrder_Create'

         ,  @n_MBOLDetailCnt              INT = 0
         ,  @n_VendorCnt                  INT = 0
         ,  @n_StorerCnt                  INT = 0

         ,  @c_MBOLStorerkey              NVARCHAR(15)   = ''
         ,  @c_MBOLVendor                 NVARCHAR(20)   = ''
         ,  @c_Facility                   NVARCHAR(5)    = ''
         ,  @c_Storerkey                  NVARCHAR(15)   = ''

         ,  @c_Vendor                     NVARCHAR(20)   = ''
         ,  @c_MoMixVendor                NVARCHAR(10)   = ''
         ,  @c_CaseID                     NVARCHAR(20)   = ''
         ,  @c_Orderkey                   NVARCHAR(10)   = ''
         ,  @c_Store                      NVARCHAR(20)   = ''

         ,  @c_DisAllowMultiStorerOnMBOL  NVARCHAR(30)   = ''  
         ,  @c_MBOLByVendor               NVARCHAR(30)   = ''

         ,  @c_Wavedetailkey              NVARCHAR(10)   = ''

         ,  @CUR_CTN                      CURSOR
         ,  @CUR_MBORD                    CURSOR

   DECLARE @T_ORDERS TABLE   
         (  RowRef      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  Orderkey    NVARCHAR(10)   NULL
         )

   DECLARE @T_CASEID TABLE   
         (  RowRef      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  CaseID      NVARCHAR(20)   NULL
         )

   DECLARE @T_CASEORDER TABLE   
         (  Orderkey    NVARCHAR(10)   NULL
         ,  Store       NVARCHAR(18)   NULL
         ,  CaseID      NVARCHAR(20)   NULL
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
         SELECT @c_DisAllowMultiStorerOnMBOL = ISNULL(CFG.NSQLValue, '0')
         FROM NSQLConfig CFG WITH (NOLOCK)
         WHERE CFG.Configkey = 'DisAllowMultiStorerOnMBOL'

         IF @c_DisAllowMultiStorerOnMBOL = '1' AND @c_MBOLKey <> ''
         BEGIN
            SELECT TOP 1 @c_MBOLStorerkey = OH.Storerkey
                        ,@c_MBOLVendor    = ISNULL(RTRIM(OH.UserDefine05),'') 
                        ,@n_MBOLDetailCnt = 1
            FROM MBOLDETAIL MBD WITH (NOLOCK)
            JOIN ORDERS     OH  WITH (NOLOCK) ON MBD.Orderkey = OH.Orderkey
            WHERE MBD.MBOLKey = @c_MBOLKey
         END
         
         SELECT  @n_VendorCnt = COUNT( DISTINCT ISNULL(RTRIM(OH.UserDefine05),'') ) 
               , @c_Vendor    = ISNULL(MIN(RTRIM(OH.UserDefine05)),'')
               , @n_StorerCnt = COUNT( DISTINCT ISNULL(RTRIM(OH.Storerkey),'') ) 
               , @c_Storerkey = MIN(OH.Storerkey)
               , @c_Facility  = MIN(OH.Facility)
               , @c_MoMixVendor = CASE WHEN ISNULL(MAX(CL.Short), '') = 'Y' OR ISNULL(MIN(CL.ListName),'') = '' THEN 'Y' ELSE 'N' END
         FROM @T_ORDERS SO
         JOIN ORDERS OH (NOLOCK) ON SO.Orderkey = OH.Orderkey
         LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  CL.ListName = 'MBByVendor' 
                                             AND CL.Code = OH.C_IsoCntryCode
                                  
         IF @c_DisAllowMultiStorerOnMBOL = '1' 
         BEGIN
            IF (@n_StorerCnt > 1) OR 
               (@n_MBOLDetailCnt > 0 AND @c_MBOLStorerkey <> @c_Storerkey) 
            BEGIN            
               SET @n_Err = 556651
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Disallow to Mix Storer. (lsp_WaveMBOLChildOrder_Create)' 
             
               EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_MBOLkey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'ERROR' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   OUTPUT 
                     ,  @n_err         = @n_err       OUTPUT 
                     ,  @c_errmsg      = @c_errmsg    OUTPUT 
            END                           
         END

         SELECT @c_MBOLByVendor  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'MBOLByVendor')

         IF @c_MBOLByVendor = '1' 
         BEGIN
            IF  @c_MoMixVendor = 'Y' AND  
               (@n_VendorCnt > 1 OR (@n_MBOLDetailCnt > 0 AND @c_MBOLVendor <> @c_Vendor))
            BEGIN  
               SET @n_Err = 556652
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Disallow to Mix Vendor. (lsp_WaveMBOLChildOrder_Create)' 
             
               EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_MBOLkey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'ERROR' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   OUTPUT 
                     ,  @n_err         = @n_err       OUTPUT 
                     ,  @c_errmsg      = @c_errmsg    OUTPUT   
            END                         
         END

         INSERT INTO @T_CASEORDER   
            (  Orderkey
            ,  Store
            ,  CaseID
            )
         SELECT DISTINCT 
                  PD.Orderkey
               ,  Store = ISNULL(OD.UserDefine02,'')                  
               ,  CTN.CaseID
         FROM @T_CASEID CTN
         JOIN PICKDETAIL  PD WITH (NOLOCK) ON  CTN.CaseID = PD.CaseID
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON  OD.Orderkey = PD.Orderkey
                                           AND OD.OrderLineNumber = PD.OrderLineNumber
         WHERE PD.ShipFlag <> 'Y' 
         AND PD.[Status] < '9'
         AND ( OD.UserDefine09 = '' OR OD.UserDefine09 IS NULL )
         AND ( OD.UserDefine10 = '' OR OD.UserDefine10 IS NULL)


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
            SET @n_Err = 556653
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Disallow Partial Consolidate Order selected to create Child Order'
                          + '. Carton #: ' + @c_CaseID 
                          + '. (lsp_WaveMBOLChildOrder_Create) |' +  @c_CaseID 

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

      IF @c_MBOLKey = ''
      BEGIN
         BEGIN TRY
            SET @b_success = 1
            EXECUTE nspg_GetKey                                                                                                                                      
                  'MBOL'                                                                                                                                           
                  , 10                                                                                                                                                 
                  , @c_MBOLkey  OUTPUT                                                                                                                                 
                  , @b_success  OUTPUT                                                                                                                                   
                  , @n_err      OUTPUT                                                                                                                                       
                  , @c_ErrMsg   OUTPUT                                                                                                                                    
         END TRY
            
         BEGIN CATCH
            SET @n_Err     = 556654                                                                                                                             
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Error Executing nspg_GetKey - MBOL. (lsp_WaveMBOLChildOrder_Create)' 
         END CATCH
                                                                                                                                                                        
         IF @b_success <> 1 OR @n_Err <> 0                                                                                                                                   
         BEGIN 
            SET @n_Continue = 3  
            GOTO EXIT_SP
         END  
             
         BEGIN TRY
            INSERT INTO MBOL(MBOLkey, Facility )   
            VALUES(@c_MBOLkey, @c_Facility)         
         END TRY                             
                                                                                                                                       
         BEGIN CATCH                                                                                                                                                
            SET @n_Continue = 3  
            SET @c_ErrMsg  = ERROR_MESSAGE()
            SET @n_Err     = 556655  
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Insert Into MBOL Failed. (lsp_WaveMBOLChildOrder_Create) ' 
                           + '(' + @c_ErrMsg + ')' 

            IF (XACT_STATE()) = -1  
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END                                                          
            GOTO EXIT_SP     
         END CATCH  
      END

      SET @CUR_CTN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT T.Orderkey
         ,   T.Store
         ,   T.CaseID
      FROM @T_CASEORDER T
      ORDER BY T.CaseID
            ,  T.Orderkey

      OPEN @CUR_CTN
      
      FETCH NEXT FROM @CUR_CTN INTO @c_Orderkey
                                 ,  @c_Store
                                 ,  @c_CaseID                                                                              
                                       
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRY
            EXEC [dbo].[isp_ChildOrder_CreateMBOL]  
                 @c_MBOLkey   = @c_MBOLkey
               , @c_Orderkey  = @c_Orderkey
               , @c_Store     = @c_Store
               , @c_CaseID    = @c_CaseID
               , @b_Success   = @b_Success      OUTPUT
               , @n_Err       = @n_Err          OUTPUT 
               , @c_ErrMsg    = @c_ErrMsg       OUTPUT 
         END TRY

         BEGIN CATCH
            SET @n_Err = 556656
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_ChildOrder_CreateMBOL. (lsp_WaveMBOLChildOrder_Create)'   
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
                                    ,  @c_CaseID     
      END
      CLOSE @CUR_CTN
      DEALLOCATE @CUR_CTN

      -- Create Child Order in the MBOL into WaveDetail
      SET @CUR_MBORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT MBD.Orderkey
      FROM MBOLDETAIL MBD WITH (NOLOCK)
      LEFT JOIN WAVEDETAIL WD WITH (NOLOCK) ON MBD.Orderkey = WD.Orderkey
      WHERE MBD.MBolKey = @c_MBOLKey
      AND   WD.WavedetailKey IS NULL
      ORDER BY MBD.MBolLineNumber

      OPEN @CUR_MBORD
      
      FETCH NEXT FROM @CUR_MBORD INTO @c_Orderkey
                                       
      WHILE @@FETCH_STATUS <> -1
      BEGIN
        SET @b_success = 1                                                                                                                                    
         
         BEGIN TRY
            EXECUTE nspg_GetKey                                                                                                                                      
                  'WavedetailKey'                                                                                                                                           
                  , 10                                                                                                                                                 
                  , @c_WavedetailKey   OUTPUT                                                                                                                                 
                  , @b_success         OUTPUT                                                                                                                                   
                  , @n_err             OUTPUT                                                                                                                                       
                  , @c_ErrMsg          OUTPUT                                                                                                                                    
         END TRY

         BEGIN CATCH
            SET @n_Err     = 556657                                                                                                                             
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Error Executing nspg_GetKey - WavedetailKey. (lsp_WaveMBOLChildOrder_Create)'  --(Wan01) 

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
         END CATCH
                                                                                                                                                                        
         IF @b_success <> 1 OR @n_Err <> 0                                                                                                                                   
         BEGIN 
            SET @n_Continue = 3  
            GOTO EXIT_SP
         END  

         BEGIN TRY                                                                                                                                                            
            INSERT INTO WAVEDETAIL                                                                                                                               
                  (WavedetailKey, WaveKey, Orderkey, AddWho)                                                                                                    
            VALUES(@c_WavedetailKey, @c_WaveKey, @c_Orderkey, @c_UserName)
         END TRY                                  
                                                                                                                                           
         BEGIN CATCH                                                                                                                                                           
            SET @n_Continue = 3      
            SET @c_ErrMsg  = ERROR_MESSAGE()                                                                                                                               
            SET @n_Err     = 556658  
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Insert Into WAVEDETAIL Failed. (lsp_WaveMBOLChildOrder_Create) '   --(Wan01) 
                           + '( ' + @c_ErrMsg + ') ' 
                            
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
            GOTO EXIT_SP     
         END CATCH 
      
         IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey= @c_Orderkey AND (UserDefine09 = '' OR UserDefine09 IS NULL))
         BEGIN
            BEGIN TRY
               UPDATE ORDERS                                                                                                                       
               SET UserDefine09 = @c_WaveKey                                                                                                                              
                  ,TrafficCop = NULL                                                                                                                                 
                  ,EditWho    = @c_UserName                                                                                                                              
                  ,EditDate   = GETDATE()                                                                                                                             
               WHERE Orderkey = @c_Orderkey
            END TRY                                  
                                                                                                                                           
            BEGIN CATCH           
               SET @n_Continue = 3 
               SET @c_ErrMsg  = ERROR_MESSAGE() 
               SET @n_Err     = 556659               
               SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                              + ': UPDATE Orders Failed. (lsp_WaveMBOLChildOrder_Create) '   --(Wan01) 
                              + '( ' + @c_ErrMsg + ') '

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
                                      
               GOTO EXIT_SP                                                                                                                                           
            END CATCH   
         END  

         FETCH NEXT FROM @CUR_MBORD INTO @c_Orderkey
      END
      CLOSE @CUR_MBORD
      DEALLOCATE @CUR_MBORD
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveMBOLChildOrder_Create'
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