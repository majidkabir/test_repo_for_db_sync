SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_SOCombineORD_Wrapper                         */                                                                                  
/* Creation Date: 2020-07-14                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2193 -Ship Reference Unit  Stored ProceduresSQL queries*/
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.3                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2021-02-09  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-04-13  Wan01    1.2   Remove Debug select variables             */
/* 2023-04-18  Wan02    1.3   LFWM-4184 - PROD - CN  Lululemon ECOM     */
/*                            Combine Order function issues             */
/*                            Devops Conbine Script                     */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_SOCombineORD_Wrapper] 
      @c_ToOrderKey           NVARCHAR(10)
   ,  @c_OrderKeys            NVARCHAR(MAX)              --List of OrderKeys, seperated by '|'
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT 
   ,  @n_WarningNo            INT          = 0  OUTPUT   --Initial to Pass in '1', Pass In the value return By SP except RE-Finalize. RE-Finalize get logwarningno to pass in
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                     
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT   --Capture Warnings/Questions/Errors/Meassage into WMS_ERROR_LIST Table
   ,  @c_SearchSQL            NVARCHAR(MAX)= ''                                     --(WAN02)
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT            = @@TRANCOUNT  
         ,  @n_Continue                   INT            = 1

         ,  @n_BackEndProcess             INT            = 0                        --(Wan02)   

         ,  @c_TableName                  NVARCHAR(50)   = 'ORDERS'
         ,  @c_SourceType                 NVARCHAR(50)   = 'lsp_SOCombineORD_Wrapper'

         ,  @n_RowID                      INT            = 0

         ,  @c_BuyerPO                    NVARCHAR(20)   = ''
         ,  @c_ToOrderKey_New             NVARCHAR(10)   = ''

         ,  @c_PreOrderKeys               NVARCHAR(4000) = ''
         ,  @c_ToFacility                 NVARCHAR(5)    = ''
         ,  @c_ToStorerkey                NVARCHAR(15)   = ''
         ,  @c_ToShipTo                   NVARCHAR(15)   = ''
         ,  @c_ToOrderStatus              NVARCHAR(10)   = ''

         ,  @c_FromOrderkey               NVARCHAR(10)   = ''
         ,  @c_OrderList                  NVARCHAR(MAX)  = ''                       --(Wan02)
         ,  @c_Facility                   NVARCHAR(5)    = ''                       --(Wan02)
         ,  @c_Storerkey                  NVARCHAR(15)   = ''                       --(Wan02)
         ,  @c_ProcessType                NVARCHAR(10)  = 'CombORD'                 --(Wan02)   
         ,  @c_DocumentKey1               NVARCHAR(50)  = ''                        --(Wan02)
         ,  @c_CallType                   NVARCHAR(50)  = ''                        --(Wan02)    
         ,  @c_ExecCmd                    NVARCHAR(MAX) = ''                        --(Wan02)

         ,  @c_CombineOrd_SP              NVARCHAR(30)   = ''
         ,  @c_CombineOrdByMultiBatch_SP  NVARCHAR(30)   = ''                       --(Wan02)
         ,  @CUR_CBMORD                   CURSOR

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
   
      IF OBJECT_ID('tempdb..#FROMORD','U') IS NOT NULL
      BEGIN
         DROP TABLE #FROMORD
      END

      CREATE TABLE #FROMORD
         (  RowID    INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY
         ,  Orderkey NVARCHAR(10)   NOT NULL DEFAULT('')
         ) 

      IF @n_ErrGroupKey IS NULL
      BEGIN
         SET @n_ErrGroupKey = 0
      END
      
      IF @c_OrderKeys = '' 
      BEGIN
         SELECT @c_SearchSQL = dbo.fnc_ParseSearchSQL(@c_SearchSQL, 'SELECT ORDERS.Orderkey') 
         
         IF @c_SearchSQL = ''
         BEGIN
            GOTO EXIT_SP
         END        

         INSERT INTO #FROMORD (  OrderKey )   
         EXEC sp_ExecuteSQL @c_SearchSQL
         
         IF @@ROWCOUNT = 0
         BEGIN
            SET @n_Continue = 3  
            SET @n_err = 558463  
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': No Search record found'      
                          + '. (lsp_SOCombineORD_Wrapper)'  
                          
            EXEC [WM].[lsp_WriteError_List]   
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT   
               ,  @c_TableName   = @c_TableName  
               ,  @c_SourceType  = @c_SourceType  
               ,  @c_Refkey1     = @c_ToOrderKey  
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
         
         SELECT @c_OrderKeys = STRING_AGG( CONVERT(NVARCHAR(MAX),f.Orderkey)
                                 , '|' )
            WITHIN GROUP (ORDER BY f.Orderkey ASC)
         FROM #FROMORD AS f
      END
      ELSE
      BEGIN
         INSERT INTO #FROMORD (  OrderKey )                                            --(Wan02) Move Up
         SELECT DISTINCT Orderkey = VALUE FROM string_split (@c_OrderKeys,'|')
         ORDER BY Orderkey
      END
      
      --(Wan02) - START
      SELECT @c_Storerkey = ISNULL(CASE WHEN MIN(o.Storerkey) = MAX(o.Storerkey) THEN MIN(o.Storerkey)
                                        ELSE '' END,'')
         ,   @c_Facility  = ISNULL(CASE WHEN MIN(o.Facility) = MAX(o.Facility) THEN MIN(o.Facility)
                                        ELSE '' END,'')                         
      FROM #FROMORD AS f JOIN dbo.ORDERS AS o (NOLOCK) ON o.OrderKey = f.Orderkey
      
      IF @c_Storerkey = ''
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 558458
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Different Storer found in Order lists'    
                       + '. (lsp_SOCombineORD_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ToOrderKey
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
  
      IF @c_Facility = ''
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 558459
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Different Facility found in Order lists'  
                     + '. (lsp_SOCombineORD_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ToOrderKey
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

      SELECT @n_BackEndProcess = 1 
      FROM  dbo.QCmd_TransmitlogConfig qcfg WITH (NOLOCK)  
      WHERE qcfg.TableName      = 'BackEndProcessQueue'
      AND   qcfg.[App_Name]     = 'WMS'  
      AND   qcfg.DataStream     = @c_ProcessType   
      AND   qcfg.StorerKey IN (@c_Storerkey, 'ALL')
      
      SELECT @c_CombineOrdByMultiBatch_SP = Authority FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'CombineOrderByMultiBatchSP')
      
      IF @c_CombineOrdByMultiBatch_SP NOT IN ( '0', '1' ) 
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM SYS.OBJECTS WITH (NOLOCK) WHERE [Name] = @c_CombineOrdByMultiBatch_SP AND [Type] = 'P' )
         BEGIN 
            SET @n_Continue = 3
            SET @n_err = 558460
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Custom SP: ' + @c_CombineOrdByMultiBatch_SP + ' not found'  
                        + '. (lsp_SOCombineORD_Wrapper) |' + @c_CombineOrdByMultiBatch_SP

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_ToOrderKey
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
    
         SET @c_OrderList = REPLACE(@c_OrderKeys,'|',',')
       
         IF @n_BackEndProcess = 1 
         BEGIN 
            SET @c_CallType = 'WM.lsp_SOCombineORD_Wrapper'
            SET @c_ExecCmd = 'dbo.isp_CombineOrderByMultiBatchSP_Wrapper'
                           + ' @c_OrderList = ''' + @c_OrderList + ''''
                           + ',@b_Success = @b_Success OUTPUT'
                           + ',@n_Err = @n_Err OUTPUT'
                           + ',@c_ErrMsg = @c_Errmsg OUTPUT'
                           + ',@n_Continue = 1'                        
                           + ',@c_FromOrderkeyList = '''''  
         
            SET @c_DocumentKey1 = LEFT(@c_OrderKeys,10)
            IF LEN(@c_OrderKeys) > 10
            BEGIN
               SET @c_DocumentKey1 = @c_DocumentKey1 + ' (1st key of multikey)'
            END

            EXEC [WM].[lsp_BackEndProcess_Submit]                                                                                                                     
               @c_Storerkey      = @c_Storerkey
            ,  @c_ModuleID       = 'Orders' 
            ,  @c_DocumentKey1   = @c_DocumentKey1  
            ,  @c_DocumentKey2   = ''      
            ,  @c_DocumentKey3   = ''      
            ,  @c_ProcessType    = @c_ProcessType   
            ,  @c_SourceType     = @c_SourceType    
            ,  @c_CallType       = @c_CallType
            ,  @c_RefKey1        = ''      
            ,  @c_RefKey2        = ''      
            ,  @c_RefKey3        = ''   
            ,  @c_ExecCmd        = @c_ExecCmd  
            ,  @c_StatusMsg      = 'Submitted to BackEndProcessQueue.'
            ,  @b_Success        = @b_Success   OUTPUT  
            ,  @n_err            = @n_err       OUTPUT                                                                                                             
            ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT  
            ,  @c_UserName       = '' 
         
            IF @b_Success = 0 
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 558461
               SET @c_ErrMsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing WM.lsp_BackEndProcess_Submit - CombineOrderByMultiBatch'
                     + '. (lsp_SOCombineORD_Wrapper) ( ' + @c_ErrMsg + ' )'
               
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_ToOrderKey
                  ,  @c_Refkey2     = @c_FromOrderKey
                  ,  @c_Refkey3     = '' 
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success    
                  ,  @n_err         = @n_err        
                  ,  @c_errmsg      = @c_errmsg  

               GOTO EXIT_SP
            END
         END
         ELSE
         BEGIN
            EXEC [dbo].[isp_CombineOrderByMultiBatchSP_Wrapper]    
               @c_OrderList         = @c_OrderList          
            ,  @b_Success           = @b_Success            
            ,  @n_Err               = @n_Err             
            ,  @c_Errmsg            = @c_Errmsg           OUTPUT  
            ,  @n_Continue          = @n_Continue         OUTPUT  
            ,  @c_FromOrderkeyList  = ''
      
            IF @b_Success = 0
            BEGIN
               SET @n_Continue = 3
               GOTO EXIT_SP
            END
         END
         GOTO EXIT_SP    
      END
      --(Wan02) - END

      --INSERT INTO #FROMORD (  OrderKey )                                          --Move Up
      --SELECT DISTINCT Orderkey = VALUE FROM string_split (@c_OrderKeys,'|')
      --ORDER BY Orderkey

      SET @c_PreOrderKeys = @c_OrderKeys

      SELECT @c_ToFacility    = OH.Facility                                         --(Wan02) Move Up
         ,   @c_ToStorerkey   = OH.Storerkey
         ,   @c_ToShipTo      = OH.ConsigneeKey
         ,   @c_ToOrderStatus = OH.[Status]
         ,   @c_BuyerPO = ISNULL(RTRIM(OH.BuyerPO),'')                              
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Orderkey = @c_ToOrderKey
      
      --select @c_ToOrderKey '@c_ToOrderKey 1'              --Wan01
      IF @c_BuyerPO <> '' -- Get the TO Orderkey if buyerpo not the min value
      BEGIN
         SET @c_ToOrderKey_New = ''
         SELECT TOP 1 @c_ToOrderKey_New = OH.Orderkey
                     ,@n_RowId = TORD.RowID
         FROM #FROMORD TORD
         JOIN ORDERS OH WITH (NOLOCK) ON TORD.Orderkey = OH.OrderKey
         ORDER BY ISNULL(OH.BuyerPO,'') 


         IF @c_ToOrderKey_New < @c_ToOrderKey
         BEGIN
            DELETE #FROMORD WHERE RowID = @n_RowId
    
            INSERT INTO #FROMORD (Orderkey) VALUES (@c_ToOrderKey)
    
            SET @c_PreOrderKeys = REPLACE(@c_PreOrderKeys, @c_ToOrderKey_New, @c_ToOrderKey)

            SET @c_ToOrderKey = @c_ToOrderKey_New
         END
      END -- END

      --select @c_ToOrderKey '@c_ToOrderKey 2'              --(Wan01)
      --SELECT @c_ToFacility    = OH.Facility               --(Wan02) - Move Up
      --   ,   @c_ToStorerkey   = OH.Storerkey
      --   ,   @c_ToShipTo      = OH.ConsigneeKey
      --   ,   @c_ToOrderStatus = OH.[Status]
      --FROM ORDERS OH WITH (NOLOCK)
      --WHERE OH.Orderkey = @c_ToOrderKey
      
      SELECT @c_CombineOrd_SP = Authority FROM dbo.fnc_SelectGetRight(@c_ToFacility, @c_ToStorerkey, '', 'CombineOrderSP')

      IF @c_CombineOrd_SP IN ( '0','1','' )
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 558451
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Custom CombineOrderSP Not setup'  
                     + '. (lsp_SOCombineORD_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ToOrderKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg    
      END
      ELSE IF NOT EXISTS (SELECT 1 FROM SYS.OBJECTS WITH (NOLOCK) WHERE [Name] = @c_CombineOrd_SP AND [Type] = 'P' )
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 558452
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Custom SP: ' + @c_CombineOrd_SP + ' not found'  
                     + '. (lsp_SOCombineORD_Wrapper) |' + @c_CombineOrd_SP

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ToOrderKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg  
      END
           
      BEGIN TRY
         SET @b_Success = 1
         SET @n_err = 0
         EXEC isp_PreCombineOrder_Wrapper
               @c_ToOrderkey  = @c_ToOrderKey
            ,  @c_OrderList   = @c_PreOrderKeys
            ,  @b_Success     = @b_Success   OUTPUT
            ,  @n_Err         = @n_Err       OUTPUT
            ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 558453
         SET @c_ErrMsg = ERROR_MESSAGE()
      END CATCH

      IF @b_Success = 0
      BEGIN
         SET @n_err = 558453
      END

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing isp_PreCombineOrder_Wrapper. (lsp_SOCombineORD_Wrapper)'
                     + ' ( ' + @c_ErrMsg + ' )'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ToOrderKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg    
      END

      --- Check ToShip, Storerkey, ORder Status
     
      SET @c_FromOrderkey = ''
      SELECT TOP 1 @c_FromOrderkey = OH.Orderkey
      FROM #FROMORD TORD
      JOIN ORDERS OH WITH (NOLOCK) ON TORD.Orderkey = OH.OrderKey
      --WHERE OH.Storerkey <> @c_ToStorerkey                                                          --(Wan02)

      IF @c_FromOrderkey <> '' AND (@c_Storerkey <> @c_ToStorerkey OR @c_Facility <> @c_ToFacility)   --(Wan02)
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 558454
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Invalid selected Order: ' + @c_FromOrderkey 
                     + '. Cannot combine different Storer and/or facility. (lsp_SOCombineORD_Wrapper)'--(Wan02)

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ToOrderKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg    
      END

      SET @c_FromOrderkey = ''
      SELECT TOP 1 @c_FromOrderkey = OH.Orderkey
      FROM #FROMORD TORD
      JOIN ORDERS OH WITH (NOLOCK) ON TORD.Orderkey = OH.OrderKey
      WHERE OH.ConsigneeKey <> @c_ToShipTo

      IF @c_FromOrderkey <> ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 558455
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Invalid selected Order: ' + @c_FromOrderkey 
                     + '. Cannot combine different Consigneekey. (lsp_SOCombineORD_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ToOrderKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg    
      END
                  
      SET @c_FromOrderkey = ''
      SELECT TOP 1 @c_FromOrderkey = OH.Orderkey
      FROM #FROMORD TORD
      JOIN ORDERS OH WITH (NOLOCK) ON TORD.Orderkey = OH.OrderKey
      WHERE OH.[Status] <> @c_ToOrderStatus
      ORDER BY OH.Orderkey

      IF @c_FromOrderkey <> ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 558456
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Invalid selected Order: ' + @c_FromOrderkey 
                     + '. Cannot combine different Status. (lsp_SOCombineORD_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ToOrderKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg    
      END

      IF @n_Continue = 3
      BEGIN
         GOTO EXIT_SP
      END
         
      SET @CUR_CBMORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TORD.OrderKey
      FROM #FROMORD TORD
      WHERE TORD.OrderKey NOT IN ( @c_ToOrderKey )

      OPEN @CUR_CBMORD

      FETCH NEXT FROM @CUR_CBMORD INTO @c_FromOrderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @n_BackEndProcess = 1                                                   --(Wan02) - START
         BEGIN 
            SET @c_CallType = 'WM.lsp_SOCombineORD_Wrapper'
            SET @c_ExecCmd = @c_CombineOrd_SP
                           + ' @c_FromOrderKey= ''' + @c_FromOrderKey + ''''
                           + ',@c_ToOrderKey  = ''' + @c_ToOrderKey + ''''
                           + ',@b_Success = @b_Success OUTPUT'
                           + ',@n_Err = @n_Err OUTPUT'
                           + ',@c_ErrMsg = @c_Errmsg OUTPUT'
         
            SET @c_DocumentKey1 = @c_FromOrderkey
 
            EXEC [WM].[lsp_BackEndProcess_Submit]                                                                                                                     
               @c_Storerkey      = @c_Storerkey
            ,  @c_ModuleID       = 'Orders' 
            ,  @c_DocumentKey1   = @c_DocumentKey1  
            ,  @c_DocumentKey2   = ''      
            ,  @c_DocumentKey3   = ''      
            ,  @c_ProcessType    = @c_ProcessType   
            ,  @c_SourceType     = @c_SourceType    
            ,  @c_CallType       = @c_CallType
            ,  @c_RefKey1        = ''      
            ,  @c_RefKey2        = ''      
            ,  @c_RefKey3        = ''   
            ,  @c_ExecCmd        = @c_ExecCmd  
            ,  @c_StatusMsg      = 'Submitted to BackEndProcessQueue.'
            ,  @b_Success        = @b_Success   OUTPUT  
            ,  @n_err            = @n_err       OUTPUT                                                                                                             
            ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT  
            ,  @c_UserName       = '' 
            
            IF @b_Success = 0 
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 558462
               SET @c_ErrMsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing WM.lsp_BackEndProcess_Submit - CombineOrderSP' + 
                     + '. (lsp_SOCombineORD_Wrapper) ( ' + @c_ErrMsg + ' )'
               
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_ToOrderKey
                  ,  @c_Refkey2     = @c_FromOrderKey
                  ,  @c_Refkey3     = '' 
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success    
                  ,  @n_err         = @n_err        
                  ,  @c_errmsg      = @c_errmsg  

               GOTO EXIT_SP
            END
         END
         ELSE
         BEGIN
            BEGIN TRY
               SET @b_Success = 1
               SET @n_Err = 0
               EXEC @c_CombineOrd_SP
                  @c_FromOrderKey= @c_FromOrderKey
               ,  @c_ToOrderKey  = @c_ToOrderKey
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_Err         = @n_Err       OUTPUT
               ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT
            END TRY
            
            BEGIN CATCH
               SET @n_Err = 558457
               SET @c_ErrMsg = ERROR_MESSAGE()
            END CATCH

            IF @b_Success = 0
            BEGIN
               SET @n_Err = 558457
            END

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing ' + @c_CombineOrd_SP
                     + '. (lsp_SOCombineORD_Wrapper) ( ' + @c_ErrMsg + ' )'
               
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_ToOrderKey
                  ,  @c_Refkey2     = @c_FromOrderKey
                  ,  @c_Refkey3     = '' 
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success    
                  ,  @n_err         = @n_err        
                  ,  @c_errmsg      = @c_errmsg  

               GOTO EXIT_SP
            END
         END                                                                        --(Wan02) - END
         FETCH NEXT FROM @CUR_CBMORD INTO @c_FromOrderkey
      END
      CLOSE @CUR_CBMORD
      DEALLOCATE @CUR_CBMORD

      IF @n_Continue = 1 AND @n_BackEndProcess = 0                                  --(Wan02)
      BEGIN
         SET @c_errmsg = 'Combine Order SuccessFully.'

         EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_ToOrderKey
         ,  @c_Refkey2     = ''
         ,  @c_Refkey3     = '' 
         ,  @c_WriteType   = 'MESSAGE' 
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success    
         ,  @n_err         = @n_err        
         ,  @c_errmsg      = @c_errmsg  
      END 
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
   EXIT_SP:

   IF OBJECT_ID('tempdb..#FROMORD','U') IS NOT NULL
   BEGIN
      DROP TABLE #FROMORD
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
      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_SOCombineORD_Wrapper'
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