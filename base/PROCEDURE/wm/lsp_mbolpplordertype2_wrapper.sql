SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/                                                                                  
/* Store Procedure: lsp_MBOLPPLOrderType2_Wrapper                       */                                                                                  
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
CREATE   PROC [WM].[lsp_MBOLPPLOrderType2_Wrapper] 
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

   DECLARE  @n_StartTCnt      INT            = @@TRANCOUNT  
         ,  @n_Continue       INT            = 1
         ,  @n_SeqNo          INT            = 0

         ,  @c_TableName      NVARCHAR(50)   = 'Loadplan'
         ,  @c_SourceType     NVARCHAR(50)   = 'lsp_MBOLPPLOrderType2_Wrapper'

         ,  @c_Facility       NVARCHAR(5)    = ''
         ,  @c_Orderkey       NVARCHAR(10)   = ''
         ,  @c_ExternOrderKey NVARCHAR(30)   = ''
         ,  @c_C_Company      NVARCHAR(15)   = ''
         ,  @c_Route          NVARCHAR(10)   = ''
         ,  @dt_DeliveryDate  DATETIME
         ,  @dt_OrderDate     DATETIME

         ,  @n_MBOLLineNo     INT            = 0
         ,  @c_MBOLLineNumber NVARCHAR(10)   = ''

         ,  @CUR_MDET         CURSOR   
         ,  @CUR_PPLORD       CURSOR      


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

      EXEC isp_MBOL_PopulateValidation
            @c_MBOLKey     = @c_MBOLKey
         ,  @c_OrderkeyList= @c_OrderKeys
         ,  @b_Success     = @b_Success   OUTPUT
         ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT
     
      IF @b_Success  = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 558401
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing isp_MBOL_PopulateValidation. (lsp_MBOLPPLOrderType2_Wrapper) '
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
          
         GOTO EXIT_SP      
      END

      IF @n_continue = 1
      BEGIN
         SET @CUR_MDET = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT MD.MBOLLineNumber
         FROM MBOLDETAIL MD WITH (NOLOCK) 
         WHERE MD.MBOLKey = @c_MBOLKey
         AND MD.Orderkey = ''
         ORDER BY MD.MBOLLineNumber

         OPEN @CUR_MDET

         FETCH NEXT FROM @CUR_MDET INTO @c_MBOLLineNumber

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DELETE MBOLDETAIL
            WHERE MBOLKey = @c_MBOLKey
            AND   MBOLLineNumber = @c_MBOLLineNumber
            FETCH NEXT FROM @CUR_MDET INTO @c_MBOLLineNumber

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 558402
               SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Update MBOLDETAIL. (lsp_MBOLPPLOrderType2_Wrapper)'

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
                  
               GOTO EXIT_SP
            END
            FETCH NEXT FROM @CUR_MDET INTO @c_MBOLLineNumber
         END
         CLOSE @CUR_MDET
         DEALLOCATE @CUR_MDET
      END
 
      IF @n_continue = 1
      BEGIN
         SET @CUR_PPLORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT OH.Facility
               ,OH.Orderkey
               ,ExternOrderKey= ISNULL(OH.ExternOrderKey,'')
               ,C_Company     = ISNULL(OH.C_Company,'')
               ,[Route]       = ISNULL(OH.[Route],'')
               ,OH.DeliveryDate
               ,OH.OrderDate
         FROM #MBOLPPLORD TORD 
         JOIN ORDERS OH WITH (NOLOCK) ON TORD.Orderkey = OH.Orderkey
         ORDER BY TORD.RowID

         OPEN @CUR_PPLORD

         FETCH NEXT FROM @CUR_PPLORD INTO @c_Facility
                                       ,  @c_Orderkey
                                       ,  @c_ExternOrderKey
                                       ,  @c_C_Company
                                       ,  @c_Route
                                       ,  @dt_DeliveryDate
                                       ,  @dt_OrderDate

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRY
               SET @b_Success = 0
               SET @n_err = 0
               EXEC dbo.isp_InsertMBOLDetail 
                     @cMBOLKey         = @c_MBOLKey
                  ,  @cFacility        = @c_Facility
                  ,  @cOrderKey        = @c_Orderkey
                  ,  @cLoadKey         = ''
                  ,  @nStdGrossWgt     = 0.00
                  ,  @nStdCube         = 0.00
                  ,  @cExternOrderKey  = @c_ExternOrderKey
                  ,  @dOrderDate       = @dt_OrderDate
                  ,  @dDelivery_Date   = @dt_DeliveryDate 
                  ,  @cRoute           = @c_Route           
                  ,  @b_Success        = @b_Success        OUTPUT
                  ,  @n_err            = @n_err            OUTPUT
                  ,  @c_errmsg         = @c_errmsg         OUTPUT
            END TRY

            BEGIN CATCH
               SET @n_err = 558403
               SET @c_ErrMsg = ERROR_MESSAGE()
            END CATCH

            IF @b_Success = 0  
            BEGIN
               SET @n_err = 558403
            END   

            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing isp_InsertMBOLDetail. (lsp_MBOLPPLOrderType2_Wrapper) '
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
                                          ,  @c_ExternOrderKey
                                          ,  @c_C_Company
                                          ,  @c_Route
                                          ,  @dt_DeliveryDate
                                          ,  @dt_OrderDate
         END
         CLOSE @CUR_PPLORD
         DEALLOCATE @CUR_PPLORD

         IF @n_Continue = 1 
         BEGIN
            SET @c_errmsg = 'Populated Orders Successfully.'

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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_MBOLPPLOrderType2_Wrapper'
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