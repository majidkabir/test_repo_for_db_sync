SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*****************************************************************************/        
/* Store Procedure: isp_ValidateChannelTransferDetail                        */        
/* Creation Date:                                                            */        
/* Copyright: LFL                                                            */        
/* Written by: Wan                                                           */        
/*                                                                           */        
/* Purpose: WMS-6492 - [JDSPORTS] RG - Create new Channel Transfer module    */        
/*                                                                           */        
/* Called By: PowerBuilder Upon ChannelTransferDetail ue_wrapup Event        */        
/*                                                                           */        
/* PVCS Version: 1.0                                                         */   
/*                                                                           */        
/* Version: 7.0                                                              */        
/*                                                                           */        
/* Data Modifications:                                                       */        
/*                                                                           */        
/* Updates:                                                                  */        
/* Date         Author    Ver.  Purposes                                     */  
/* 16-Aug-2021  NJOW01    1.1   WMS-17740 Allow finalize zero qty for itf    */
/*****************************************************************************/        
        
CREATE PROCEDURE [dbo].[isp_ValidateChannelTransferDetail]        
  @c_XMLSchemaString    NVARCHAR(MAX) 
, @c_XMLDataString      NVARCHAR(MAX) 
, @b_Success            INT OUTPUT
, @n_Err                INT OUTPUT
, @c_ErrMsg             NVARCHAR(250) OUTPUT
, @n_WarningNo          INT = 0       OUTPUT
, @c_ProceedWithWarning CHAR(1) = 'N'
, @c_IsSupervisor       CHAR(1) = 'N' 
, @c_XMLDataString_Prev NVARCHAR(MAX) = ''
AS 
BEGIN   
    SET ANSI_NULLS ON
   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON   
   SET QUOTED_IDENTIFIER ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON
  
   DECLARE     
      @x_XMLSchema         XML
   ,  @x_XMLData           XML 
   ,  @c_TableColumns      NVARCHAR(MAX) = N''
   ,  @c_ColumnName        NVARCHAR(128) = N''
   ,  @c_DataType          NVARCHAR(128) = N''
   ,  @c_TableName         NVARCHAR(30)  = N''
   ,  @c_SQL               NVARCHAR(MAX) = N''
   ,  @c_SQLSchema         NVARCHAR(MAX) = N''
   ,  @c_SQLData           NVARCHAR(MAX) = N''   
   ,  @n_Continue          INT = 1 
   
   --NJOW01
   DECLARE
     @c_ChannelFromInvMgmt          NVARCHAR(30)
   , @c_Option1                     NVARCHAR(50)  
   , @c_Option2                     NVARCHAR(50) 
   , @c_Option3                     NVARCHAR(50) 
   , @c_Option4                     NVARCHAR(50) 
   , @c_Option5                     NVARCHAR(4000) 
   , @c_ChannelTransferAllowFNZ0Qty NVARCHAR(30) 
      
   IF OBJECT_ID('tempdb..#CHANNELTRANSFERDETAIL') IS NOT NULL
   BEGIN
      DROP TABLE #CHANNELTRANSFERDETAIL
   END

   CREATE TABLE #CHANNELTRANSFERDETAIL( Rowid  INT NOT NULL IDENTITY(1,1) )   

   SET @x_XMLSchema = CONVERT(XML, @c_XMLSchemaString)
   SET @x_XMLData = CONVERT(XML, @c_XMLDataString)

   DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT x.value('@ColName', 'NVARCHAR(128)') AS columnname
         ,x.value('@DataType','NVARCHAR(128)') AS datatype
   FROM @x_XMLSchema.nodes('/Table/Column') TempXML (x)
      
   OPEN CUR_SCHEMA

   FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_TableName = ''
      IF CHARINDEX('.', @c_ColumnName) > 0 
      BEGIN
         SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))
         SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))
      END

      SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_DataType + ' NULL, '
      SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '
      SET @c_SQLData = @c_SQLData + 'x.value(''@' + @c_TableName + @c_ColumnName + ''', ''' + @c_DataType + ''') AS ['  + @c_ColumnName + '], '
         
      FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
   END
   CLOSE CUR_SCHEMA
   DEALLOCATE CUR_SCHEMA
       
       
   IF LEN(@c_SQLSchema) > 0 
   BEGIN
      SET @c_SQL = N'ALTER TABLE #CHANNELTRANSFERDETAIL  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
         
      EXEC (@c_SQL)

      SET @c_SQL = N' INSERT INTO #CHANNELTRANSFERDETAIL' --+  @c_UpdateTable 
                  + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                  + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                  + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
         
      EXEC sp_executeSQl @c_SQL
                        , N'@x_XMLData xml'
                        , @x_XMLData
   END

   DECLARE @c_FromStorerkey         NVARCHAR(15)      
         , @c_FromSku               NVARCHAR(20) 
         , @c_FromPackkey           NVARCHAR(10) 
         , @c_FromUOM               NVARCHAR(10)               
         , @c_FromChannel           NVARCHAR(10)      
         , @c_FromC_Attribute01     NVARCHAR(30)      
         , @c_FromC_Attribute02     NVARCHAR(30)      
         , @c_FromC_Attribute03     NVARCHAR(30)      
         , @c_FromC_Attribute04     NVARCHAR(30)      
         , @c_FromC_Attribute05     NVARCHAR(30)      
         , @n_FromQty               INT               
         , @c_ToStorerkey           NVARCHAR(15)      
         , @c_ToSku                 NVARCHAR(20)    
         , @c_ToPackkey             NVARCHAR(10) 
         , @c_ToUOM                 NVARCHAR(10)              
         , @c_ToChannel             NVARCHAR(10)      
         , @c_ToC_Attribute01       NVARCHAR(30)      
         , @c_ToC_Attribute02       NVARCHAR(30)      
         , @c_ToC_Attribute03       NVARCHAR(30)      
         , @c_ToC_Attribute04       NVARCHAR(30)      
         , @c_ToC_Attribute05       NVARCHAR(30)      
         , @n_ToQty                 INT               

         , @c_C_AttributeLabel01    NVARCHAR(30)      
         , @c_C_AttributeLabel02    NVARCHAR(30)      
         , @c_C_AttributeLabel03    NVARCHAR(30)      
         , @c_C_AttributeLabel04    NVARCHAR(30)      
         , @c_C_AttributeLabel05    NVARCHAR(30)  

   SET @c_FromStorerkey    = ''                  
   SET @c_FromSku          = ''                  
   SET @c_FromChannel      = ''                  
   SET @c_FromC_Attribute01= ''                  
   SET @c_FromC_Attribute02= ''                  
   SET @c_FromC_Attribute03= ''                  
   SET @c_FromC_Attribute04= ''                  
   SET @c_FromC_Attribute05= ''                  
   SET @n_FromQty          = 0                   
   SET @c_ToStorerkey      = ''                  
   SET @c_ToSku            = ''                  
   SET @c_ToChannel        = ''                  
   SET @c_ToC_Attribute01  = ''                  
   SET @c_ToC_Attribute02  = ''                  
   SET @c_ToC_Attribute03  = ''                  
   SET @c_ToC_Attribute04  = ''                  
   SET @c_ToC_Attribute05  = ''                  
   SET @n_ToQty            = 0                   

   SELECT @c_FromStorerkey    = CTD.FromStorerkey
         ,@c_FromSku          = CTD.FromSku
         ,@c_FromPackkey      = FromPackkey
         ,@c_FromUOM          = FromUOM
         ,@c_FromChannel      = CTD.FromChannel
         ,@c_FromC_Attribute01= CTD.FromC_Attribute01
         ,@c_FromC_Attribute02= CTD.FromC_Attribute02
         ,@c_FromC_Attribute03= CTD.FromC_Attribute03
         ,@c_FromC_Attribute04= CTD.FromC_Attribute04
         ,@c_FromC_Attribute05= CTD.FromC_Attribute05
         ,@n_FromQty          = CTD.FromQty
         ,@c_ToStorerkey      = CTD.ToStorerkey
         ,@c_ToSku            = CTD.ToSku
         ,@c_ToPackkey        = ToPackkey
         ,@c_ToUOM            = ToUOM
         ,@c_ToChannel        = CTD.ToChannel
         ,@c_ToC_Attribute01  = CTD.ToC_Attribute01
         ,@c_ToC_Attribute02  = CTD.ToC_Attribute02
         ,@c_ToC_Attribute03  = CTD.ToC_Attribute03
         ,@c_ToC_Attribute04  = CTD.ToC_Attribute04
         ,@c_ToC_Attribute05  = CTD.ToC_Attribute05
         ,@n_ToQty            = CTD.ToQty
   FROM #CHANNELTRANSFERDETAIL CTD WITH (NOLOCK)


   SET @c_C_AttributeLabel01 = ''
   SET @c_C_AttributeLabel02 = ''
   SET @c_C_AttributeLabel03 = ''
   SET @c_C_AttributeLabel04 = ''
   SET @c_C_AttributeLabel05 = ''

   SELECT @c_C_AttributeLabel01  = ISNULL(RTRIM(CFG.C_AttributeLabel01),'')
         ,@c_C_AttributeLabel02  = ISNULL(RTRIM(CFG.C_AttributeLabel02),'')
         ,@c_C_AttributeLabel03  = ISNULL(RTRIM(CFG.C_AttributeLabel03),'')
         ,@c_C_AttributeLabel04  = ISNULL(RTRIM(CFG.C_AttributeLabel04),'')
         ,@c_C_AttributeLabel05  = ISNULL(RTRIM(CFG.C_AttributeLabel05),'')
   FROM CHANNELATTRIBUTECONFIG CFG WITH (NOLOCK)
   WHERE Storerkey = @c_FromStorerkey
   
   --NJOW01 S
   Execute nspGetRight2      
      @c_Facility  = ''
   ,  @c_StorerKey = @c_FromStorerKey        -- Storer
   ,  @c_sku       =''                      -- Sku
   ,  @c_ConfigKey = 'ChannelInventoryMgmt'  -- ConfigKey
   ,  @b_Success   = @b_success             OUTPUT
   ,  @c_authority = @c_ChannelFromInvMgmt  OUTPUT
   ,  @n_err       = @n_err                 OUTPUT
   ,  @c_errmsg    = @c_ErrMsg              OUTPUT
   ,  @c_Option1   = @c_Option1             OUTPUT 
   ,  @c_Option2   = @c_Option2             OUTPUT 
   ,  @c_Option3   = @c_Option3             OUTPUT 
   ,  @c_Option4   = @c_Option4             OUTPUT 
   ,  @c_Option5   = @c_Option5             OUTPUT 
   
   SELECT @c_ChannelTransferAllowFNZ0Qty = dbo.fnc_GetParamValueFromString('@c_ChannelTransferAllowFNZ0Qty', @c_Option5, 'N')
   --NJOW01 E
   
   IF @c_FromSku = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62010
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Sku is Required'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_ToSku = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62020
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Sku is Required'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_FromChannel = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62030
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Channel is Required'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_ToChannel = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62040
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Channel is Required'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_FromPackkey = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62050
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Packkey is Required'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_ToPackkey = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62060
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Packkey is Required'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_FromUOM = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62070
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From UOM is Required'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_ToUOM = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62080
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To UOM is Required'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @n_FromQty = 0 AND @c_ChannelTransferAllowFNZ0Qty <> 'Y'  --NJOW01
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62090
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ':  From Qty in lowest UOM is 0'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @n_ToQty = 0 AND @c_ChannelTransferAllowFNZ0Qty <> 'Y' --NJOW01
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62100
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Qty in lowest UOM is 0'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @n_FromQty <> @n_ToQty
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62110
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Qty <> To Qty'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_C_AttributeLabel01 = '' AND @c_FromC_Attribute01 <> ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62120
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Channel Attribute 01 is not set up. Empty From Channel Attribute01'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_C_AttributeLabel02= '' AND @c_FromC_Attribute02 <> ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62130
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Channel Attribute 02 is not set up. Empty From Channel Attribute02'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_C_AttributeLabel03 = '' AND @c_FromC_Attribute03 <> ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62140
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Channel Attribute 03 is not set up. Empty From Channel Attribute03'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_C_AttributeLabel04 = '' AND @c_FromC_Attribute04 <> ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62150
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Channel Attribute 04 is not set up. Empty From Channel Attribute04'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   IF @c_C_AttributeLabel05 = '' AND @c_FromC_Attribute05 <> ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62160
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Channel Attribute 05 is not set up. Empty From Channel Attribute05'
                      + '. isp_ValidateChannelTransferDetail)' 
      GOTO QUIT_SP
   END

   SET @c_C_AttributeLabel01 = ''
   SET @c_C_AttributeLabel02 = ''
   SET @c_C_AttributeLabel03 = ''
   SET @c_C_AttributeLabel04 = ''
   SET @c_C_AttributeLabel05 = ''

   SELECT @c_C_AttributeLabel01  = ISNULL(RTRIM(CFG.C_AttributeLabel01),'')
         ,@c_C_AttributeLabel02  = ISNULL(RTRIM(CFG.C_AttributeLabel02),'')
         ,@c_C_AttributeLabel03  = ISNULL(RTRIM(CFG.C_AttributeLabel03),'')
         ,@c_C_AttributeLabel04  = ISNULL(RTRIM(CFG.C_AttributeLabel04),'')
         ,@c_C_AttributeLabel05  = ISNULL(RTRIM(CFG.C_AttributeLabel05),'')
   FROM CHANNELATTRIBUTECONFIG CFG WITH (NOLOCK)
   WHERE Storerkey = @c_ToStorerkey

   IF @c_C_AttributeLabel01= '' AND @c_ToC_Attribute01 <> ''                                                                   
   BEGIN  
      SET @n_Continue = 3                                                                                                        
      SET @n_Err      = 62170                                                                                                    
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Channel Attribute 01 is not set up. Empty To Channel Attribute01'
                      + '. isp_ValidateChannelTransferDetail)'                                                                        
      GOTO QUIT_SP                                                                                                               
   END                                                                                                                           
                                                                                                                                 
                                                                                                                                 
   IF @c_C_AttributeLabel02= '' AND @c_ToC_Attribute02 <> ''                                                                   
   BEGIN                                                                                                                         
      SET @n_Continue = 3                                                                                                        
      SET @n_Err      = 62180                                                                                                   
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Channel Attribute 02 is not set up. Empty To Channel Attribute02'
                      + '. isp_ValidateChannelTransferDetail)'                                                                        
      GOTO QUIT_SP                                                                                                               
   END                                                                                                                           
                                                                                                                                 
   IF @c_C_AttributeLabel03 = '' AND @c_ToC_Attribute03 <> ''                                                                  
   BEGIN                                                                                                                         
      SET @n_Continue = 3                                                                                                        
      SET @n_Err      = 62190                                                                                                   
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Channel Attribute 03 is not set up. Empty To Channel Attribute03'
                      + '. isp_ValidateChannelTransferDetail)'                                                                        
      GOTO QUIT_SP                                                                                                               
   END                                                                                                                           
                                                                                                                                 
   IF @c_C_AttributeLabel04 = '' AND @c_ToC_Attribute04 <> ''                                                                  
   BEGIN                                                                                                                         
      SET @n_Continue = 3                                                                                                        
      SET @n_Err      = 62200                                                                                                    
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Channel Attribute 04 is not set up. Empty To Channel Attribute04'
                      + '. isp_ValidateChannelTransferDetail)'                                                                        
      GOTO QUIT_SP                                                                                                               
   END                                                                                                                           
                                                                                                                                 
   IF @c_C_AttributeLabel05 = '' AND @c_ToC_Attribute05 <> ''                                                                  
   BEGIN                                                                                                                         
      SET @n_Continue = 3                                                                                                        
      SET @n_Err      = 62210                                                                                                  
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Channel Attribute 05 is not set up. Empty To Channel Attribute05'
                      + '. isp_ValidateChannelTransferDetail)'                                                                        
      GOTO QUIT_SP                                                                                                               
   END                  

   QUIT_SP:    
   SET  @b_Success = 1
      
   IF   @n_continue = 3
   BEGIN
      SET @b_Success = 0
   END        
END
-- end procedure   

GO