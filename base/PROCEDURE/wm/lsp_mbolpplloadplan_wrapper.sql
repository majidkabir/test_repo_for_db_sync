SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_MBOLPPLLoadPlan_Wrapper                      */                                                                                  
/* Creation Date: 2020-07-10                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2193 -Ship Reference Unit  Stored ProceduresSQL queries*/
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
/* 2021-02-05  mingle01 1.1   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_MBOLPPLLoadPlan_Wrapper] 
      @c_MBOLKey              NVARCHAR(10)
   ,  @c_OrderKeys            NVARCHAR(4000)             --List of OrderKeys, seperated by '|'
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT 
   ,  @n_WarningNo            INT          = 0  OUTPUT   --Initial to Pass in '1', Pass In the value return By SP except RE-Finalize. RE-Finalize get logwarningno to pass in
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                     
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT   --Capture Warnings/Questions/Errors/Meassage into WMS_ERROR_LIST Table
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT            = @@TRANCOUNT  
         ,  @n_Continue                   INT            = 1

         ,  @b_MultiStorer                BIT            = 0
         ,  @n_DistinctStorer_PPL         INT            = 0
         ,  @n_DistinctStorer_MD          INT            = 0
         ,  @c_Storer_PPL                 NVARCHAR(15)   = ''
         ,  @c_Storer_MD                  NVARCHAR(15)   = ''

         ,  @c_TableName                  NVARCHAR(50)   = 'Loadplan'
         ,  @c_SourceType                 NVARCHAR(50)   = 'lsp_MBOLPPLLoadPlan_Wrapper'

         ,  @n_NoOfVendor                 INT            = 0
         ,  @c_Vendor                     NVARCHAR(30)   = ''
         ,  @c_PromptErr                  NVARCHAR(10)   = ''
         ,  @c_VendorInCL                 NVARCHAR(30)   = ''

         ,  @c_Facility                   NVARCHAR(5)    = ''
         ,  @c_Storerkey                  NVARCHAR(15)   = ''
         ,  @c_Orderkey                   NVARCHAR(10)   = ''
         ,  @c_Loadkey                    NVARCHAR(10)   = ''
         ,  @c_ExternOrderKey             NVARCHAR(30)   = ''
         ,  @c_C_Company                  NVARCHAR(15)   = ''
         ,  @c_Route                      NVARCHAR(10)   = ''
         ,  @dt_DeliveryDate              DATETIME
         ,  @dt_OrderDate                 DATETIME
         ,  @n_Weight                     FLOAT
         ,  @n_Cube                       FLOAT

         ,  @c_NSQLConfigKey              NVARCHAR(30)   = ''
         ,  @c_DisallowMultiStorerOnMBOL  NVARCHAR(30)   = ''

         ,  @c_MBOLByVendor               NVARCHAR(30)   = ''

         ,  @CUR_PPLORD                   CURSOR      

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
      IF OBJECT_ID('tempdb..#MBOLPPLORD','U') IS NOT NULL
      BEGIN
         DROP TABLE #MBOLPPLORD
      END

      CREATE TABLE #MBOLPPLORD
         (  RowID    INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY
         ,  Orderkey NVARCHAR(10)   NOT NULL DEFAULT('')
         ) 

      IF @n_ErrGroupKey IS NULL
      BEGIN
         SET @n_ErrGroupKey = 0
      END
   
      INSERT INTO #MBOLPPLORD (  OrderKey )
      SELECT DISTINCT Orderkey = VALUE FROM string_split (@c_OrderKeys,'|')
      ORDER BY Orderkey

      ----- Check Multi Storer on a MBOL
      SET @c_NSQLConfigKey = "DisAllowMultiStorerOnMBOL"

      SELECT @c_DisAllowMultiStorerOnMBOL = ISNULL(NSQLValue,'0')
      FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey = @c_NSQLConfigKey

      IF @c_DisAllowMultiStorerOnMBOL = '1'
      BEGIN
         SET @n_DistinctStorer_PPL = 0
         SET @c_Storer_PPL   = ''

         SELECT @n_DistinctStorer_PPL = COUNT(DISTINCT OH.Storerkey)
               ,@c_Storer_ppl  = ISNULL(MIN(OH.Storerkey),'')
         FROM #MBOLPPLORD TORD
         JOIN ORDERS      OH WITH (NOLOCK) ON TORD.Orderkey = OH.Orderkey 

         IF @n_DistinctStorer_PPL > 1 
         BEGIN
            SET @b_MultiStorer = 1
         END
      
         IF @b_MultiStorer = 0
         BEGIN
            SET @n_DistinctStorer_MD = 0
            SET @c_Storer_MD   = ''
                       
            SELECT @n_DistinctStorer_MD = COUNT(DISTINCT OH.Storerkey)
                 , @c_Storer_MD = ISNULL(MIN(OH.Storerkey),'')
            FROM MBOLDETAIL MD WITH (NOLOCK)
            JOIN ORDERS     OH WITH (NOLOCK) ON MD.Orderkey = OH.Orderkey
            WHERE MD.MBOLKey = @c_MBOLKey

            IF @n_DistinctStorer_PPL > 1 
            BEGIN
               SET @b_MultiStorer = 1
            END
         END
 
         IF @b_MultiStorer = 0
         BEGIN
            IF (@n_DistinctStorer_PPL = 1 AND @n_DistinctStorer_MD = 1) AND
               (@c_Storer_PPL <> @c_Storer_MD)
            BEGIN
               SET @b_MultiStorer = 1
            END
         END

         IF @b_MultiStorer = 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 558351
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Disallow Multiple Storer on Ship Ref Unit. (lsp_MBOLPPLLoadPlan_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_MBOLKey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = '' 
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success    
               ,  @n_err         = @n_err        
               ,  @c_errmsg      = @c_errmsg    
         END
      END

      --- Check Multiple Vendor on a MBOL

      SET @c_Facility = ''
      SET @c_Storerkey= ''

      SELECT TOP 1  
              @c_Facility = OH.Facility 
            , @c_Storerkey = OH.Storerkey
      FROM MBOLDETAIL MD WITH (NOLOCK)
      JOIN ORDERS     OH WITH (NOLOCK) ON MD.Orderkey = OH.Orderkey
      WHERE MD.MBOLKey = @c_MBOLKey

      IF @c_Storerkey = ''
      BEGIN
         SELECT TOP 1
               @c_Facility = OH.Facility 
            ,  @c_Storerkey = OH.Storerkey
         FROM #MBOLPPLORD TORD
         JOIN ORDERS OH   WITH (NOLOCK) ON TORD.Orderkey = OH.OrderKey
         ORDER BY RowID
      END

      SET @c_MBOLByVendor = ''
      SELECT @c_MBOLByVendor = dbo.fnc_GetRight (@c_Facility, @c_Storerkey, "", "MBOLByVendor")

      IF @c_MBOLByVendor = '1'
      BEGIN
         SET @n_NoOfVendor = 0
         SET @c_Vendor     = ''
         SET @c_PromptErr  = ''
         SET @c_VendorInCL = ''

         SELECT @n_NoOfVendor = COUNT(DISTINCT ISNULL(OH.UserDefine05,''))
               ,@c_Vendor     = ISNULL(MAX(OH.UserDefine05),'')
               ,@c_PromptErr  = ISNULL(MAX(CL.Short),'')
               ,@c_VendorInCL = ISNULL(MIN(CL.Code),'')
         FROM #MBOLPPLORD TORD
         JOIN ORDERS OH   WITH (NOLOCK) ON TORD.Orderkey = OH.OrderKey
         LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName = 'MBBYVENDOR'  
                                                   AND CL.Code = OH.C_IsoCntryCode
         
         IF @n_NoOfVendor <= 1
         BEGIN
            SELECT @n_NoOfVendor = 2
            FROM MBOLDETAIL MD WITH (NOLOCK)
            JOIN ORDERS     OH WITH (NOLOCK) ON (MD.Orderkey= OH.ORderkey)
            WHERE MD.Mbolkey = @c_mbolkey
            AND   OH.UserDefine05 <> @c_Vendor
         END
         
         IF @n_NoOfVendor > 1 AND (@c_PromptErr = 'Y' OR @c_VendorInCL = '')
         BEGIN
            SET @n_continue = 3
            SET @n_err = 558352
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Cannot Mix Vendor on Ship Ref Unit For Storer: ' + @c_Storerkey
                           + '. (lsp_MBOLPPLLoadPlan_Wrapper) |' + @c_Storerkey

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_MBOLKey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = '' 
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success    
               ,  @n_err         = @n_err        
               ,  @c_errmsg      = @c_errmsg   
         END  
      END

      EXEC isp_MBOL_PopulateValidation
            @c_MBOLKey     = @c_MBOLKey
         ,  @c_OrderkeyList= @c_OrderKeys
         ,  @b_Success     = @b_Success   OUTPUT
         ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT
     
      IF @b_Success  = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 558353
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing isp_MBOL_PopulateValidation. (lsp_MBOLPPLLoadPlan_Wrapper) '
                  + '( ' + @c_errmsg + ' )'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_MBOLKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg    
      END

      IF @n_continue = 3
      BEGIN
         GOTO EXIT_SP  
      END

      IF @n_continue = 1
      BEGIN
         SET @CUR_PPLORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT OH.Facility
               ,OH.Orderkey
               ,OH.LoadKey
               ,ExternOrderKey= ISNULL(OH.ExternOrderKey,'')
               ,C_Company     = ISNULL(OH.C_Company,'')
               ,[Route]       = ISNULL(OH.[Route],'')
               ,OH.DeliveryDate
               ,OH.OrderDate
               ,LPD.[Weight]
               ,LPD.[Cube]
         FROM #MBOLPPLORD TORD 
         JOIN ORDERS OH WITH (NOLOCK) ON TORD.Orderkey = OH.Orderkey
         JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON OH.Orderkey = LPD.Orderkey
         ORDER BY TORD.RowID

         OPEN @CUR_PPLORD

         FETCH NEXT FROM @CUR_PPLORD INTO @c_Facility
                                       ,  @c_Orderkey
                                       ,  @c_Loadkey
                                       ,  @c_ExternOrderKey
                                       ,  @c_C_Company
                                       ,  @c_Route
                                       ,  @dt_DeliveryDate
                                       ,  @dt_OrderDate
                                       ,  @n_Weight
                                       ,  @n_Cube

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRY
               SET @b_Success = 1
               SET @n_err = 0
               EXEC dbo.isp_InsertMBOLDetail 
                     @cMBOLKey         = @c_MBOLKey
                  ,  @cFacility        = @c_Facility
                  ,  @cOrderKey        = @c_Orderkey
                  ,  @cLoadKey         = @c_Loadkey
                  ,  @nStdGrossWgt     = @n_Weight
                  ,  @nStdCube         = @n_Cube
                  ,  @cExternOrderKey  = @c_ExternOrderKey
                  ,  @dOrderDate       = @dt_OrderDate
                  ,  @dDelivery_Date   = @dt_DeliveryDate 
                  ,  @cRoute           = @c_Route           
                  ,  @b_Success        = @b_Success        OUTPUT
                  ,  @n_err            = @n_err            OUTPUT
                  ,  @c_errmsg         = @c_errmsg         OUTPUT
            END TRY

            BEGIN CATCH
               SET @n_err = 558354
               SET @c_errmsg = ERROR_MESSAGE()
            END CATCH

            IF @b_Success = 0  
            BEGIN
               SET @n_err = 558354
            END   

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing isp_InsertMBOLDetail. (lsp_MBOLPPLLoadPlan_Wrapper) '
                             + '( ' + @c_errmsg + ' )'

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_MBOLKey
                  ,  @c_Refkey2     = @c_Orderkey
                  ,  @c_Refkey3     = '' 
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success    
                  ,  @n_err         = @n_err        
                  ,  @c_errmsg      = @c_errmsg  
                  
               GOTO EXIT_SP
            END

            FETCH NEXT FROM @CUR_PPLORD INTO @c_Facility
                                          ,  @c_Orderkey
                                          ,  @c_Loadkey
                                          ,  @c_ExternOrderKey
                                          ,  @c_C_Company
                                          ,  @c_Route
                                          ,  @dt_DeliveryDate
                                          ,  @dt_OrderDate
                                          ,  @n_Weight
                                          ,  @n_Cube

         END
         CLOSE @CUR_PPLORD
         DEALLOCATE @CUR_PPLORD
   
         IF @n_Continue = 1 
         BEGIN
            SET @c_errmsg = 'Populate Load Plan Successfully.'

            EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_MBOLKey
            ,  @c_Refkey2     = @c_Orderkey
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'MESSAGE' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg
         END  
      END
   
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_MBOLPPLLoadPlan_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
      
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END

   REVERT
END

GO