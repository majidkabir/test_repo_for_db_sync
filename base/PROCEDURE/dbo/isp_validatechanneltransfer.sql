SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*****************************************************************************/        
/* Store Procedure: isp_ValidateChannelTransfer                              */        
/* Creation Date:                                                            */        
/* Copyright: LFL                                                            */        
/* Written by: Wan                                                           */        
/*                                                                           */        
/* Purpose: WMS-6492 - [JDSPORTS] RG - Create new Channel Transfer module    */        
/*                                                                           */        
/* Called By: PowerBuilder Upon ChannelTransfer ue_wrapup Event              */        
/*                                                                           */        
/* PVCS Version: 1.1                                                         */   
/*                                                                           */        
/* Version: 7.0                                                              */        
/*                                                                           */        
/* Data Modifications:                                                       */        
/*                                                                           */        
/* Updates:                                                                  */        
/* Date         Author     Ver.  Purposes                                    */ 
/* 2019-07-19   Wan01      1.1   WMS-9872 - CN_NIKESDC_Exceed_Channel        */
/*****************************************************************************/        
        
CREATE PROCEDURE [dbo].[isp_ValidateChannelTransfer]        
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

   IF OBJECT_ID('tempdb..#CHANNELTRANSFER') IS NOT NULL
   BEGIN
      DROP TABLE #CHANNELTRANSFER
   END

   CREATE TABLE #CHANNELTRANSFER( Rowid  INT NOT NULL IDENTITY(1,1) )   

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
      SET @c_SQL = N'ALTER TABLE #CHANNELTRANSFER  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
         
      EXEC (@c_SQL)

      SET @c_SQL = N' INSERT INTO #CHANNELTRANSFER' --+  @c_UpdateTable 
                  + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                  + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                  + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
         
      EXEC sp_executeSQl @c_SQL
                        , N'@x_XMLData xml'
                        , @x_XMLData
   END

   DECLARE @c_FromStorerkey         NVARCHAR(15)      
         , @c_FromFacility          NVARCHAR(5)           
         , @c_ToStorerkey           NVARCHAR(15)      
         , @c_ToFacility            NVARCHAR(5)      
  
         , @c_ChannelFromInvMgmt    NVARCHAR(30)
         , @c_ChannelToInvMgmt      NVARCHAR(30)


   SELECT @c_FromStorerkey = CT.FromStorerkey
         ,@c_ToStorerkey   = CT.ToStorerkey
         ,@c_FromFacility  = CT.Facility
         ,@c_ToFacility    = CT.ToFacility
   FROM #CHANNELTRANSFER CT WITH (NOLOCK)

   IF @c_FromFacility = ''
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': From Facility is required'
                    + '. isp_ValidateChannelTransfer) '  
      GOTO QUIT_SP
   END

   IF @c_ToFacility = ''
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62020
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': To Facility is required'
                    + '. isp_ValidateChannelTransfer) '  
      GOTO QUIT_SP
   END

   SET @c_ChannelFromInvMgmt = '0'
   SET @b_success = 0
   Execute nspGetRight2       --Wan01 
      @c_FromFacility
   ,  @c_FromStorerKey        -- Storer
   ,  ''                      -- Sku
   ,  'ChannelInventoryMgmt'  -- ConfigKey
   ,  @b_success              OUTPUT
   ,  @c_ChannelFromInvMgmt   OUTPUT
   ,  @n_err                  OUTPUT
   ,  @c_ErrMsg               OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62030
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspGetRight'
                    + '. isp_ValidateChannelTransfer) ' + ISNULL(RTRIM(@c_ErrMsg),'')
      GOTO QUIT_SP
   END

   SET @c_ChannelToInvMgmt = '0'
   SET @b_success = 0
   Execute nspGetRight2       --Wan01
      @c_ToFacility
   ,  @c_ToStorerKey          -- Storer
   ,  ''                      -- Sku
   ,  'ChannelInventoryMgmt'  -- ConfigKey
   ,  @b_success              OUTPUT
   ,  @c_ChannelToInvMgmt     OUTPUT
   ,  @n_err                  OUTPUT
   ,  @c_ErrMsg               OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62040
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspGetRight'
                    + '. isp_ValidateChannelTransfer) ' + ISNULL(RTRIM(@c_ErrMsg),'')
      GOTO QUIT_SP
   END

   IF @c_ChannelFromInvMgmt = '0' OR @c_ChannelToInvMgmt = '0' --(Wan01) Both From /To ChannelInventoryMgmt Must turn on
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62050
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Either From/To Facility & Storerkey does not setup Channel Inventory.'--(Wan01) 
                    + '. isp_ValidateChannelTransfer) ' + ISNULL(RTRIM(@c_ErrMsg),'')

      GOTO QUIT_SP
   END

   QUIT_SP:     
   SET @b_Success = 1
   IF   @n_continue = 3
   BEGIN
      SET @b_Success = 0
   END 
END
-- end procedure   

GO