SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/    
/* Stored Procedure: isp_Wrapup_Validation                                */    
/* Creation Date: 04-dec-2014                                             */    
/* Copyright: LFL                                                         */    
/* Written by:                                                            */    
/*                                                                        */    
/* Purpose: SOS#326186 - PH - Location Host Warehouse Code Mandatory      */  
/*                                                                        */    
/* Called By: n_cst_busobj.ue_wrapup                                      */    
/*                                                                        */    
/* PVCS Version: 1.2                                                      */    
/*                                                                        */    
/* Version: 7.0                                                           */    
/*                                                                        */    
/* Data Modifications:                                                    */    
/*                                                                        */    
/* Updates:                                                               */    
/* Date         Author   Ver  Purposes                                    */   
/* 09-JUL-2015  YTWan    1.1  SOS#346642 - Project Merlion - Kitting      */  
/*                            Lottable06 Validation (Wan01)               */  
/* 23-JUN-2017  Wan02    1.2  WMS-2282-Validation on Work Order           */  
/* 08-JAN-2018  Wan03    1.3  Merge CN Live DB Version                    */  
/* 02-OCT-2019  NJOW01   1.4  Remove TempDB.INFORMATION_SCHEMA.Columns    */  
/* 20-DEC-2018  Wan04    1.4  WM-Move FrontEnd Record Not Found validate  */  
/*                            to SP For'w_userdefine_extended_validation' */  
/* 21-AUG-2020  NJOW02   1.5  Fix invalid column error                    */ 
/* 12-NOV-2020  NJOW03   1.6  INC1339334 - Fix bypassed validation while  */ 
/*                            saving WaveDetail                           */
/* 11-Jun-2021  NJOW04   1.7  WMS-17231 include inventoryhold validation  */
/* 11-Jun-2021  NJOW04   1.7  DEVOPS Combine script                       */
/* 15-AUG-2022  Wan05    1.8  LFWM-3669 - VN ¿C ADIDAS- WMS-SCE¿CAdding   */
/*                            Validation for Location Type of Module      */
/*                            Assign Pick Location                        */
/* 09-Mar-2023  NJOW05   1.9  LFWM-3608 Performance tuning for XML reading*/ 
/**************************************************************************/  
CREATE   PROCEDURE [dbo].[isp_Wrapup_Validation]    
      @c_Window            NVARCHAR(60) = ''  
   ,  @c_BusObj            NVARCHAR(30) = ''  
   ,  @c_UpdateTable       NVARCHAR(30)  
   ,  @c_XMLSchemaString   NVARCHAR(MAX)   
   ,  @c_XMLDataString     NVARCHAR(MAX)   
   ,  @b_Success           INT OUTPUT      
   ,  @n_Err               INT OUTPUT  
   ,  @c_Errmsg            NVARCHAR(255) OUTPUT  
AS    
BEGIN    
   SET ANSI_NULLs ON  
   SET ANSI_PADDING ON  
   SET ANSI_WARNINGS ON  
   SET QUOTED_IDENTIFIER ON  
   SET CONCAT_NULL_YIELDS_NULL ON  
   SET ARITHABORT ON  
  
   DECLARE @c_SQL             NVARCHAR(MAX)  
         , @c_SQLSchema       NVARCHAR(MAX)  
         , @c_SQLData         NVARCHAR(MAX)  
  
         , @c_TableColumns    NVARCHAR(MAX)  
         , @c_ColumnName      NVARCHAR(128)  
         , @c_DataType        NVARCHAR(128)  
         , @x_XMLSchema       XML  
         , @x_XMLData         XML  
  
         , @c_ColLength       NVARCHAR(5)  
         , @n_RecFound        INT    
         , @b_InValid         INT   
         , @c_ListName        NVARCHAR(10)  
         , @c_Facility        NVARCHAR(5)  
         , @c_Storerkey       NVARCHAR(15)     
         , @c_TableName       NVARCHAR(30)   
         , @c_Description     NVARCHAR(250)   
         , @c_Condition       NVARCHAR(1000)   
         , @c_Type            NVARCHAR(10)  
         , @c_ColName         NVARCHAR(128)   
         , @c_ColType         NVARCHAR(128)  
         , @c_SQLJoin         NVARCHAR(4000)  
         , @c_WhereCondition  NVARCHAR(4000)  
  
         , @n_Cnt             INT  
         , @c_PrimaryKey1     NVARCHAR(30)  
         , @c_PrimaryKey2     NVARCHAR(30)  
         , @c_PrimaryKey3     NVARCHAR(30)  
         , @c_SPName          NVARCHAR(50)  
  
         , @c_ValidateBy      NVARCHAR(30)  
         , @c_CfgValSourceCol NVARCHAR(30) 
         , @c_Lot             NVARCHAR(10)
         , @c_Loc             NVARCHAR(10)
         , @c_ID              NVARCHAR(18)
         , @c_Sku             NVARCHAR(20) 
         , @n_XMLHandle          INT                  --NJOW05
         , @c_SQLSchema_OXML     NVARCHAR(MAX) = N''  --NJOW05
         , @c_TableColumns_OXML  NVARCHAR(MAX) = N''  --NJOW05              
         , @c_SQL2               NVARCHAR(MAX) = N''  --NJOW05
         , @c_XMLToTemp          NVARCHAR(1) = 'N'  --NJOW01
  
   SET @n_err        = 0  
   SET @b_Success   = 1  
   SET @c_errmsg     = ''  
  
   SET @c_SQL        = ''  
   SET @c_SQLSchema  = ''  
   SET @c_SQLData    = ''  
   
   SET @c_ColumnName = ''  
   SET @c_TableColumns= ''  
   SET @c_DataType   = ''  
   SET @c_ListName   = ''  
  
  
   -- Build temp table structure & Insert Data to Temp table (START)     
   IF OBJECT_ID('tempdb..#VALDN') IS NOT NULL         
      AND @c_Window = 'w_userdefine_extended_validation'  --NJOW05
   BEGIN  
      DROP TABLE #VALDN  
   END  

   --NJOW05 S
   IF OBJECT_ID('tempdb..#SCHEMA') IS NOT NULL         
      AND @c_Window = 'w_userdefine_extended_validation'  
   BEGIN  
      DROP TABLE #SCHEMA  
   END  
   --NJOW05 E
       
   IF OBJECT_ID('tempdb..#VALDN') IS NULL --NJOW05 
   BEGIN
      CREATE TABLE #VALDN( Rowid  INT NOT NULL IDENTITY(1,1) PRIMARY KEY)  --(Wan03)  
      SET @c_XMLToTemp = 'Y'
   END
       
   IF OBJECT_ID('tempdb..#SCHEMA') IS NULL --NJOW05      
      CREATE TABLE #SCHEMA (Column_Name NVARCHAR(80), Data_Type NVARCHAR(80)) --NJOW01  
       
   IF @c_Window = 'w_userdefine_extended_validation'  
   BEGIN           
      SET @c_ListName = @c_XMLSchemaString   
      SET @c_WhereCondition = @c_XMLDataString  
      IF @c_ListName = ''   
      BEGIN  
         SET @b_InValid = 1  
         GOTO QUIT_SP  
      END  
  
      IF @c_WhereCondition <> ''  
      BEGIN  
         SET @c_WhereCondition = 'WHERE ' + @c_WhereCondition  
      END  
  
      DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT col.column_name  
            ,col.data_type  
            ,Col.CHARACTER_MAXIMUM_LENGTH  
      FROM INFORMATION_SCHEMA.COLUMNS Col WITH (NOLOCK)  
      WHERE col.Table_Name = @c_UpdateTable  
      ORDER BY ORDINAL_POSITION  
  
      OPEN CUR_SCHEMA  
  
      FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_datatype, @c_ColLength  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         --NJOW01  
         INSERT INTO #SCHEMA (Column_Name, Data_Type)  
         VALUES (@c_ColumnName, @c_datatype)  
     
         SET @c_datatype = @c_datatype + CASE @c_datatype WHEN 'numeric' THEN '(15,5)'  
                                                          WHEN 'nvarchar' THEN '(' + @c_ColLength + ')'  
                                                          ELSE '' END  
         IF @c_datatype <> 'timestamp'  
         BEGIN  
            SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_datatype + ' NULL, '  
            SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '  
         END  
                    
         FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_datatype, @c_ColLength  
      END  
      CLOSE CUR_SCHEMA  
      DEALLOCATE CUR_SCHEMA  
  
      IF @c_SQLSchema <> ''  
      BEGIN  
         SET @c_SQL = N'ALTER TABLE #VALDN  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '  
  
         EXEC (@c_SQL)  
  
         SET @c_SQL = N' INSERT INTO #VALDN' --+  @c_UpdateTable   
                   + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'  
                    + ' SELECT ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1)   
                    + ' FROM ' + @c_updatetable + ' WITH (NOLOCK) '  
                    + @c_WhereCondition  
  
         EXEC (@c_SQL)  
           
         --(Wan04) - START  
         IF NOT EXISTS (SELECT 1 FROM #VALDN)  
         BEGIN  
            SET @b_InValid = 1  
            SET @c_Errmsg  = 'Record Not Found'  
            GOTO QUIT_SP  
         END  
         --(Wan04) - END           
  
      END  
   END  
   ELSE IF @c_XMLToTemp = 'Y'  --NJOW05
   BEGIN           	
      SET @x_XMLSchema = CONVERT(XML, @c_XMLSchemaString)  
      SET @x_XMLData = CONVERT(XML, @c_XMLDataString)  

      --NJOW05 S      
      EXEC sp_xml_preparedocument @n_XMLHandle OUTPUT, @c_XMLSchemaString      
      DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT ColName, DataType 
         FROM OPENXML (@n_XMLHandle, '/Table/Column',1)  
         WITH (ColName  NVARCHAR(128),  
               DataType NVARCHAR(128))
        
      OPEN CUR_SCHEMA  
  
      FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_datatype  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SET @c_TableName = ''  
         IF CHARINDEX('.', @c_ColumnName) > 0   
         BEGIN  
            SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))  
            SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))  
         END  
  
         SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_datatype + ' NULL, '  
         SET @c_SQLSchema_OXML  = @c_SQLSchema_OXML + '['+@c_TableName+@c_ColumnName + '] ' + @c_DataType + ', '
         SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '  
         SET @c_TableColumns_OXML = @c_TableColumns_OXML + '[' + @c_TableName + @c_ColumnName + '], '
                    
         --NJOW01  
         IF CHARINDEX('(', @c_datatype) > 0  
         BEGIN  
              SET @c_datatype = LTRIM(RTRIM(LEFT(@c_datatype, CHARINDEX('(', @c_datatype) - 1)))  
         END  
           
         INSERT INTO #SCHEMA (Column_Name, Data_Type)  
         VALUES (@c_ColumnName, @c_datatype)  
           
         FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_datatype  
      END  
      CLOSE CUR_SCHEMA  
      DEALLOCATE CUR_SCHEMA      
      EXEC sp_xml_removedocument @n_XMLHandle            
  
      IF @c_SQLSchema <> ''  
      BEGIN  
         SET @c_SQL = N'ALTER TABLE #VALDN  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '  
  
         EXEC (@c_SQL)  
  
         EXEC sp_xml_preparedocument @n_XMLHandle OUTPUT, @c_XMLDataString

         
         SET @c_SQL = N' INSERT INTO #VALDN' 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_TableColumns_OXML, 1, LEN(@c_TableColumns_OXML) - 1)
                     + ' FROM  OPENXML (@n_XMLHandle, ''Row'',1) '
                     + ' WITH (' + SUBSTRING(@c_SQLSchema_OXML, 1, LEN(@c_SQLSchema_OXML) - 1) + ')'
                        
         EXEC sp_executeSQl @c_SQL
                           , N'@n_XMLHandle INT'
                           , @n_XMLHandle              
                                                                                               
         EXEC sp_xml_removedocument @n_XMLHandle            
      END
      --NJOW05 E
  
      /*
      DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT x.value('@ColName', 'NVARCHAR(128)') AS columnname  
            ,x.value('@DataType','NVARCHAR(128)') AS datatype  
      FROM @x_XMLSchema.nodes('/Table/Column') TempXML (x)  
        
      OPEN CUR_SCHEMA  
  
      FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_datatype  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SET @c_TableName = ''  
         IF CHARINDEX('.', @c_ColumnName) > 0   
         BEGIN  
            SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))  
            SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))  
         END  
  
         SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_datatype + ' NULL, '  
         SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '  
         SET @c_SQLData = @c_SQLData + 'x.value(''@' + @c_TableName + @c_ColumnName + ''', ''' + @c_datatype + ''') AS ['  + @c_ColumnName + '], '  
           
         --NJOW01  
         IF CHARINDEX('(', @c_datatype) > 0  
         BEGIN  
              SET @c_datatype = LTRIM(RTRIM(LEFT(@c_datatype, CHARINDEX('(', @c_datatype) - 1)))  
         END  
           
         INSERT INTO #SCHEMA (Column_Name, Data_Type)  
         VALUES (@c_ColumnName, @c_datatype)  
           
         FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_datatype  
      END  
      CLOSE CUR_SCHEMA  
      DEALLOCATE CUR_SCHEMA  
  
      IF @c_SQLSchema <> ''  
      BEGIN  
         SET @c_SQL = N'ALTER TABLE #VALDN  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '  
  
         EXEC (@c_SQL)  
  
         SET @c_SQL = N' INSERT INTO #VALDN' --+  @c_UpdateTable   
                   + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'  
                    + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1)   
                    + ' FROM @x_XMLData.nodes(''Row'') TempXML (x)'  
  
         EXEC sp_executeSQl @c_SQL  
                         , N'@x_XMLData xml'  
                         , @x_XMLData  
      END
      */  
   END   
  
   -- Build temp table structure & Insert Data to Temp table (END)  
  
   -- Validation Check (START)     
   SET @c_SQLJoin = CASE WHEN @c_UpdateTable = 'TRANSFERDETAIL'  
                         THEN ' JOIN STORER WITH (NOLOCK) ON (TRANSFERDETAIL.FromStorerkey = STORER.Storerkey)'  
                            + ' LEFT JOIN SKU WITH (NOLOCK) ON (TRANSFERDETAIL.FromStorerkey = SKU.Storerkey)'  
                            +                             ' AND(TRANSFERDETAIL.FromSku = SKU.Sku)'  
                            + ' LEFT JOIN LOT WITH (NOLOCK) ON (TRANSFERDETAIL.FromLot = LOT.Lot)'  
                            + ' LEFT JOIN LOC WITH (NOLOCK) ON (TRANSFERDETAIL.FromLoc = LOC.Loc)'  
                            + ' LEFT JOIN ID  WITH (NOLOCK) ON (TRANSFERDETAIL.FromID  = ID.Id)'  
                            + ' JOIN STORER TOSTORER WITH (NOLOCK) ON (TRANSFERDETAIL.ToStorerkey = TOSTORER.Storerkey)'  
                            + ' LEFT JOIN SKU    TOSKU    WITH (NOLOCK) ON (TRANSFERDETAIL.ToStorerkey = TOSKU.Storerkey)'  
                            +                                         ' AND(TRANSFERDETAIL.ToSku = TOSKU.Sku)'  
                            + ' LEFT JOIN LOC    TOLOC    WITH (NOLOCK) ON (TRANSFERDETAIL.ToLoc = TOLOC.Loc)'  
                         WHEN @c_UpdateTable = 'ADJUSTMENTDETAIL'  
                         THEN ' JOIN STORER WITH (NOLOCK) ON (ADJUSTMENTDETAIL.Storerkey = STORER.Storerkey)'  
                            + ' LEFT JOIN SKU WITH (NOLOCK) ON (ADJUSTMENTDETAIL.Storerkey = SKU.Storerkey)'  
                            +                       ' AND(ADJUSTMENTDETAIL.Sku = SKU.Sku)'  
                            + ' LEFT JOIN LOT WITH (NOLOCK) ON (ADJUSTMENTDETAIL.Lot = LOT.Lot)'  
                            + ' LEFT JOIN LOC WITH (NOLOCK) ON (ADJUSTMENTDETAIL.Loc = LOC.Loc)'  
                            + ' LEFT JOIN ID  WITH (NOLOCK) ON (ADJUSTMENTDETAIL.ID  = ID.Id)'  
                         --(Wan01) - START  
                         WHEN @c_UpdateTable = 'KITDETAIL'  
                         THEN ' JOIN STORER WITH (NOLOCK) ON (KITDETAIL.Storerkey = STORER.Storerkey)'  
                            + ' LEFT JOIN SKU WITH (NOLOCK) ON (KITDETAIL.Storerkey = SKU.Storerkey)'  
                            +                             ' AND(KITDETAIL.Sku = SKU.Sku)'  
                            + ' LEFT JOIN LOT WITH (NOLOCK) ON (KITDETAIL.Lot = LOT.Lot)'  
                            + ' LEFT JOIN LOC WITH (NOLOCK) ON (KITDETAIL.Loc = LOC.Loc)'  
                            + ' LEFT JOIN ID  WITH (NOLOCK) ON (KITDETAIL.ID  = ID.Id)'  
                         --(Wan01) - END  
                         --(Wan02) - START  
                         WHEN @c_UpdateTable = 'WORKORDERDETAIL'  
                         THEN ' JOIN STORER WITH (NOLOCK) ON (WORKORDERDETAIL.Storerkey = STORER.Storerkey)'  
                            + ' LEFT JOIN SKU WITH (NOLOCK) ON (WORKORDERDETAIL.Storerkey = SKU.Storerkey)'  
                            +                             ' AND(WORKORDERDETAIL.Sku = SKU.Sku)'  
                         WHEN @c_UpdateTable = 'WORKORDER'  
                         THEN ' JOIN STORER WITH (NOLOCK) ON (WORKORDER.Storerkey = STORER.Storerkey)'  
                         --(Wan02) - END  
                         WHEN @c_UpdateTable = 'WAVE'  
                         THEN ' LEFT JOIN WAVEDETAIL WITH (NOLOCK) ON (WAVE.Wavekey = WAVEDETAIL.Wavekey)'  
                            + ' LEFT JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)'  
                         WHEN @c_UpdateTable = 'WAVEDETAIL'  
                         THEN ' LEFT JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)'  
                         WHEN @c_UpdateTable = 'LOADPLAN'  
                         THEN ' LEFT JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey)'  
                            + ' LEFT JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)'  
                         WHEN @c_UpdateTable = 'LOADPLANDETAIL'  
                         THEN ' JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)'  
                         WHEN @c_UpdateTable = 'MBOL'  
                         THEN ' LEFT JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLkey = MBOLDETAIL.MBOLkey)'  
                            + ' LEFT JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)'  
                         WHEN @c_UpdateTable = 'MBOLDETAIL'  
                         THEN ' LEFT JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)'  
                            + ' LEFT JOIN LOADPLANDETAIL WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = LOADPLANDETAIL.Orderkey)'  
                            + ' LEFT JOIN LOADPLAN       WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey)'  
                         WHEN @c_UpdateTable = 'SKU'  
                         THEN ' LEFT JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)'  
                         WHEN @c_UpdateTable = 'LOC'  
                         THEN ' LEFT JOIN FACILITY WITH (NOLOCK) ON (LOC.Facility = FACILITY.Facility)'  
                            + ' LEFT JOIN PUTAWAYZONE WITH (NOLOCK) ON (LOC.Putawayzone = PUTAWAYZONE.Putawayzone)'  
                         WHEN @c_UpdateTable IN ('PODETAIL', 'RECEIPTDETAIL', 'ORDERDETAIL', 'PICKDETAIL')  
                         THEN ' JOIN SKU WITH (NOLOCK) ON (' + @c_UpdateTable + '.Storerkey = SKU.Storerkey)'  
                            +                        ' AND(' + @c_UpdateTable + '.Sku = SKU.Sku)'  
                         WHEN @c_UpdateTable = 'INVENTORYHOLD'  --NJOW04  
                         THEN ' LEFT JOIN LOT WITH (NOLOCK) ON (INVENTORYHOLD.Lot = LOT.Lot)'  
                            + ' LEFT JOIN LOC WITH (NOLOCK) ON (INVENTORYHOLD.Loc = LOC.Loc)'  
                            + ' LEFT JOIN ID  WITH (NOLOCK) ON (INVENTORYHOLD.ID = ID.ID)'  
                            + ' LEFT JOIN SKU WITH (NOLOCK) ON (INVENTORYHOLD.Storerkey = SKU.Storerkey AND INVENTORYHOLD.Sku = SKU.Sku)'
                            + ' LEFT JOIN STORER WITH (NOLOCK) ON (INVENTORYHOLD.Storerkey = STORER.Storerkey)' 
                         WHEN @c_UpdateTable = 'SKUXLOC'       --wan05 
                         THEN ' JOIN LOC WITH (NOLOCK) ON (SKUXLOC.Loc = LOC.Loc)'  
                         ELSE ''  
                         END  
  
   -- Get ListName to do validation (START)  
   IF @c_ListName = ''  
   BEGIN  
      SET @c_ValidateBy = ''  
      SET @c_CfgValSourceCol = ''  
      SELECT @c_ValidateBy = ValidateBy  
           , @c_CfgValSourceCol = CfgValSourceCol  
      FROM V_Extended_Validation  
      WHERE ValidateTable = @c_UpdateTable  
      AND ValidateTable <> ValidationType  
  
      IF @c_CfgValSourceCol = ''  
      BEGIN   
         GOTO QUIT_SP  
      END  
  
      --NJOW02 S
      SET @c_TableName = ''
      IF CHARINDEX('.', @c_CfgValSourceCol) > 0 
      BEGIN
         SET @c_TableName  = LEFT(@c_CfgValSourceCol, CHARINDEX('.', @c_CfgValSourceCol) - 1)
         SET @c_ColumnName = RIGHT(@c_CfgValSourceCol, LEN(@c_CfgValSourceCol) - (LEN(@c_TableName) + 1))
      END
      ELSE
         SET @c_ColumnName = @c_CfgValSourceCol
      
      --NJOW03 S
      IF @c_TableName <> '' AND @c_UpdateTable = @c_TableName 
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM #SCHEMA WHERE Column_Name = @c_ColumnName) 
            GOTO QUIT_SP
      END   
      ELSE IF @c_TableName <> '' AND @c_UpdateTable <> @c_TableName
      BEGIN
         IF CHARINDEX(@c_TableName, @c_SQLJoin) = 0  
            GOTO QUIT_SP                       
      END
      ELSE IF @c_TableName = '' AND ISNULL(@c_ColumnName,'') <> ''
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM #SCHEMA WHERE Column_Name = @c_ColumnName) 
            GOTO QUIT_SP        
      --NJOW03 E                         
      END
      --NJOW02 E        
      
      --NJOW04 S
      IF @c_UpdateTable = 'INVENTORYHOLD' AND @c_ValidateBy = 'Storer'  
      BEGIN
      	 SET @c_Storerkey = ''
      	 SET @c_Sku = ''
      	 
      	 --NJOW05 change to Dynamic SQL
      	 SET @c_SQL = N'
      	     SELECT TOP 1 @c_Storerkey = Storerkey,
      	                  @c_Sku = Sku,
      	                  @c_Lot = Lot,
      	                  @c_Loc = Loc,
      	                  @c_ID = ID
      	     FROM #VALDN'

         EXEC sp_executeSQl @c_SQL  
                         , N'@c_Storerkey NVARCHAR(15) OUTPUT, @c_Sku NVARCHAR(20) OUTPUT, @c_Lot NVARCHAR(10) OUTPUT, @c_Loc NVARCHAR(10) OUTPUT, @c_ID NVARCHAR(18) OUTPUT'  
                         , @c_Storerkey OUTPUT
                         , @c_Sku OUTPUT
                         , @c_Lot OUTPUT
                         , @c_Loc OUTPUT
                         , @c_ID  OUTPUT	 
      	 
      	 IF ISNULL(@c_Storerkey,'') = ''
      	 BEGIN
      	    IF ISNULL(@c_Lot,'') <> ''
      	    BEGIN
      	       SELECT @c_Storerkey = Storerkey,
      	              @c_Sku = Sku
      	       FROM LOT (NOLOCK)  
      	       WHERE Lot = @c_Lot
      	    END       
      	    ELSE IF ISNULL(@c_ID,'') <> ''
      	    BEGIN
      	    	 SELECT TOP 1 @c_Storerkey = Storerkey
      	    	 FROM LOTXLOCXID (NOLOCK)
      	    	 WHERE ID = @c_ID
      	    	 AND Qty > 0
      	    	 ORDER BY Editdate DESC      	    	       	    	       	    	 
      	    END
      	    ELSE IF ISNULL(@c_Loc,'') <> ''
      	    BEGIN
      	    	 SELECT TOP 1 @c_Storerkey = Storerkey
      	    	 FROM LOTXLOCXID (NOLOCK)
      	    	 WHERE Loc = @c_Loc
      	    	 --AND Qty > 0
      	    	 ORDER BY Editdate DESC
      	    END      	      
      	    
      	    IF ISNULL(@c_Storerkey,'') = ''
      	    BEGIN 
      	       GOTO QUIT_SP
      	    END        
      	    ELSE
      	    BEGIN
      	    	 --NJOW05 change to Dynamic SQL
               SET @c_SQL = N'      	       	    	
      	           UPDATE #VALDN
      	           SET Storerkey = @c_Storerkey,
      	           Sku = CASE WHEN ISNULL(@c_Sku,'') <> '' THEN @c_Sku ELSE Sku END'

               EXEC sp_executeSQl @c_SQL  
                         , N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20)'  
                         , @c_Storerkey 
                         , @c_Sku       	           
      	    END
      	 END
      END 
      --NJOW04 E
  
      SET @c_Facility = ''  
      SET @c_Storerkey = ''  
      IF @c_ValidateBy = 'Storer'   
      BEGIN                     
         SET @c_SQL = N'SELECT TOP 1 @c_Storerkey = ' + @c_CfgValSourceCol  
                    + ' FROM #VALDN ' +  @c_UpdateTable  
                    + @c_SQLJoin  
  
         EXEC sp_executesql @c_SQL   
            , N'@c_Storerkey NVARCHAR(15)  OUTPUT'  
            , @c_Storerkey   OUTPUT     
  
         IF @c_Storerkey = '' OR @c_Storerkey IS NULL  
         BEGIN  
            GOTO QUIT_SP  
         END  
      END  
      ELSE  
      BEGIN         
         SET @c_SQL = N'SELECT TOP 1 @c_facility = ' + @c_CfgValSourceCol  
                    + ' FROM #VALDN ' +  @c_UpdateTable  
                    + @c_SQLJoin  
  
         EXEC sp_executesql @c_SQL   
            , N'@c_facility NVARCHAR(15)  OUTPUT'  
            , @c_facility   OUTPUT     
  
         IF @c_facility = '' OR @c_facility IS NULL  
         BEGIN  
            GOTO QUIT_SP  
         END  
      END  
      -- Validation support below setup in Codelkup VALDNCFG   
      -- Storer level setup  
      -- facility level setup (for loc)  
      -- all when storerkey & facility are blank  
      SELECT TOP 1 @c_ListName = ISNULL(RTRIM(VALCFG.UDF01),'')  
      FROM V_Extended_Validation WITH (NOLOCK)  
      JOIN CODELKUP      VALCFG  WITH (NOLOCK) ON  (VALCFG.ListName = 'VALDNCFG')  
                                               AND (V_Extended_Validation.ValidationType = VALCFG.Code)  
      WHERE V_Extended_Validation.ValidateTable = @c_UpdateTable  
      AND   V_Extended_Validation.ValidationType <> V_Extended_Validation.ValidateTable   
      AND ((VALCFG.Storerkey = @c_Storerkey AND @c_Storerkey <> ''  AND     
            VALCFG.Code2  = @c_Facility  AND @c_Facility  <> '') OR                    -- Storer + Facility setup   
           (VALCFG.Storerkey = @c_Storerkey AND Storerkey <> '' AND Code2 = '') OR     -- Storer level  
         (VALCFG.Code2  = @c_Facility  AND Storerkey = '' AND  @c_Storerkey = '') OR -- Facility setup  
           (VALCFG.Storerkey = '' AND VALCFG.Code2 = ''))                              -- System setup  
      ORDER BY CASE WHEN VALCFG.Storerkey = @c_Storerkey AND @c_Storerkey <> '' AND      
                         VALCFG.Code2  = @c_Facility AND @c_Facility <> '' THEN 1                     -- Storer + Facility setup  
                    WHEN VALCFG.Storerkey = @c_Storerkey AND Storerkey <> '' AND Code2 = '' THEN 2    -- Storer level  
                    WHEN VALCFG.Code2  = @c_Facility AND Storerkey = '' AND @c_Storerkey = '' THEN 3  -- Facility setup  
                    WHEN VALCFG.Storerkey = '' AND VALCFG.Code2 = '' THEN 4                           -- System setup  
                    END  
   END   
   
   VALIDATE_REC:  
  
   DECLARE CUR_CHK_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT CLKP.Code, CLKP.Description, CLKP.Long, ISNULL(CLKP.Notes2,'')   
   FROM   CODELIST CLST WITH (NOLOCK)  
   JOIN   CODELKUP CLKP WITH (NOLOCK) ON (CLST.ListName = CLKP.ListName)  
   WHERE  CLST.ListName  = @c_ListName   
   AND    CLST.ListGroup = @c_UpdateTable  
   AND    CLKP.Short    = 'REQUIRED'  
   ORDER BY CLKP.Code  
  
   OPEN CUR_CHK_REQUIRED  
  
   FETCH NEXT FROM CUR_CHK_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition   
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @n_RecFound = 0   
        
      SET @c_SQL = N'SELECT @n_RecFound = COUNT(1)'  
                + ' FROM #VALDN ' + @c_UpdateTable   
                + @c_SQLJoin  
                + ' WHERE 1 = 1'  
          
      -- Get Column Type  
      SET @c_TableName = LEFT(@c_ColumnName, CharIndex('.', @c_ColumnName) - 1)  
      SET @c_ColName   = SUBSTRING(@c_ColumnName,   
                        CharIndex('.', @c_ColumnName) + 1, LEN(@c_ColumnName) - CharIndex('.', @c_ColumnName))  
  
      SET @c_ColType = ''  
      /*  
      SELECT @c_ColType = DATA_TYPE  
      FROM TempDB.INFORMATION_SCHEMA.Columns WITH (NOLOCK)  
      WHERE TABLE_NAME = OBJECT_NAME(OBJECT_ID('tempdb..#VALDN'), (select database_id from sys.databases WITH (NOLOCK) WHERE name = 'tempdb'))  
      AND   COLUMN_NAME = @c_ColName  
      */  
  
      --NJOW01  
      SELECT @c_ColType = DATA_TYPE  
      FROM #SCHEMA  
      WHERE COLUMN_NAME = @c_ColName        
  
      IF ISNULL(RTRIM(@c_ColType), '') = ''   
      BEGIN  
         SET @b_InValid = 1   
         SET @c_ErrMsg = 'Invalid Column Name: ' + @c_ColumnName   
         GOTO QUIT_SP  
      END   
  
      IF @c_ColType IN ('char', 'nvarchar', 'varchar')   
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (ISNULL(RTRIM(' + @c_ColumnName + '),'''') = '''' '  
      ELSE IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')  
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' = 0 '  
              
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'         
  
      EXEC sp_executesql @c_SQL, N'@n_RecFound int OUTPUT', @n_RecFound OUTPUT  
  
      IF @n_RecFound > 0    
      BEGIN   
         SET @b_InValid = 1   
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)  
      END   
  
      FETCH NEXT FROM CUR_CHK_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition    
   END   
   CLOSE CUR_CHK_REQUIRED  
   DEALLOCATE CUR_CHK_REQUIRED   
  
   IF @b_InValid = 1  
      GOTO QUIT_SP  
  
   ----------- Check Condition ------  
  
   SET @b_InValid = 0  
  
   DECLARE CUR_CHK_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT CLKP.Code, CLKP.Description, CLKP.Long, ISNULL(CLKP.Notes,''), CLKP.SHORT, ISNULL(CLKP.Notes2,'')    
   FROM   CODELIST CLST WITH (NOLOCK)  
   JOIN   CODELKUP CLKP WITH (NOLOCK) ON (CLST.ListName = CLKP.ListName)  
   WHERE  CLST.ListName  = @c_ListName   
   AND    CLST.ListGroup = @c_UpdateTable  
   AND    CLKP.SHORT    IN ('CONDITION', 'CONTAINS')  
  
   OPEN CUR_CHK_CONDITION  
  
   FETCH NEXT FROM CUR_CHK_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition    
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN     
      SET @c_SQL = N'SELECT @n_RecFound = COUNT(1)'  
                + ' FROM #VALDN ' + @c_UpdateTable   
                + @c_SQLJoin  
                + ' WHERE 1 = 1'  
  
      IF @c_Type = 'CONDITION'  
         IF ISNULL(@c_Condition,'') <> ''  
         BEGIN  
            SET @c_Condition = REPLACE(LEFT(@c_Condition,5),'AND ','AND (') + SUBSTRING(@c_Condition,6,LEN(@c_Condition)-5)  
          SET @c_Condition = REPLACE(LEFT(@c_Condition,4),'OR ','OR (') + SUBSTRING(@c_Condition,5,LEN(@c_Condition)-4)  
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_Condition),3) NOT IN ('AND','OR ') AND ISNULL(@c_Condition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_Condition)  
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'  
         END   
         ELSE  
         BEGIN  
            IF ISNULL(@c_WhereCondition,'') <> ''  
            BEGIN  
               SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)  
               SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)  
               SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'  
            END  
         END  
      ELSE  
      BEGIN --CONTAINS  
         IF ISNULL(@c_Condition,'') <> ''  
         BEGIN  
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' IN (' + ISNULL(RTRIM(@c_Condition),'') + ')'   
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'  
         END  
         ELSE  
         BEGIN  
            IF ISNULL(@c_WhereCondition,'') <> ''  
            BEGIN  
               SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)  
               SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)  
               SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'  
            END  
         END                     
      END     
  
      EXEC sp_executesql @c_SQL, N'@n_RecFound int OUTPUT', @n_RecFound OUTPUT   
  
      IF @n_RecFound = 0 AND @c_Type <> 'CONDITION'  
      BEGIN   
         SET @b_InValid = 1   
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)  
      END   
      ELSE  
      IF @n_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS'   
      BEGIN   
         SET @b_InValid = 1   
            SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)  
      END   
      ELSE  
      IF @n_RecFound = 0 AND @c_Type = 'CONDITION' AND   
         (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')    
      BEGIN   
         SET @b_InValid = 1   
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)  
      END   
        
      FETCH NEXT FROM CUR_CHK_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition    
   END   
   CLOSE CUR_CHK_CONDITION  
   DEALLOCATE CUR_CHK_CONDITION   
  
  
   IF @b_InValid = 1  
      GOTO QUIT_SP  
  
   DECLARE CUR_CHK_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT CLKP.Code, CLKP.Description, CLKP.Long   
   FROM   CODELIST CLST WITH (NOLOCK)  
   JOIN   CODELKUP CLKP WITH (NOLOCK) ON (CLST.ListName = CLKP.ListName)  
   WHERE  CLST.ListName  = @c_ListName   
   AND    CLST.ListGroup = @c_UpdateTable  
   AND    CLKP.Short    = 'STOREDPROC'  
  
   OPEN CUR_CHK_SPCONDITION  
  
   FETCH NEXT FROM CUR_CHK_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName   
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
  
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = RTRIM(@c_SPName) AND type = 'P')    
      BEGIN   
  
         IF NOT EXISTS (SELECT 1    
                        FROM [INFORMATION_SCHEMA].[PARAMETERS] WITH (NOLOCK)  
                        WHERE SPECIFIC_NAME = @c_SPName  
                        AND PARAMETER_NAME = '@x_XMLSchema'  
                        AND PARAMETER_NAME = '@x_XMLData'  
                      )  
         BEGIN  
            GOTO NEXT_SP_RULE  
         END  
  
         SET @n_Cnt = 0   
         SET @c_PrimaryKey1 = ''  
         SET @c_PrimaryKey2= ''  
         SET @c_PrimaryKey3= ''  
  
         SET @c_SQL = 'EXEC ' + @c_SPName  
  
         DECLARE CUR_PRIMARYKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Column_Name  
         FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WITH (NOLOCK)  
         WHERE OBJECTPROPERTY(OBJECT_ID(constraint_name), 'IsPrimaryKey') = 1  
         AND Table_name = @c_UpdateTable  
         AND Table_Schema = 'dbo'  
         ORDER BY ORDINAL_POSITION  
     
         OPEN CUR_PRIMARYKEY  
  
         FETCH NEXT FROM CUR_PRIMARYKEY INTO @c_ColumnName  
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
  
            IF EXISTS ( SELECT 1    
                        FROM [INFORMATION_SCHEMA].[PARAMETERS] WITH (NOLOCK)  
                        WHERE SPECIFIC_NAME = @c_SPName  
                        AND PARAMETER_NAME = '@x_XMLSchema'  
                        AND PARAMETER_NAME = '@c_' + @c_ColumnName  
                      )  
            BEGIN  
               GOTO NEXT_SP_RULE  
            END  
  
            SET @n_Cnt = @n_Cnt + 1  
            SET @c_SQL = N'SELECT @c_PrimaryKey' + CONVERT(CHAR(1), @n_Cnt) + ' = ' + @c_ColumnName  
                       + ' FROM #VALDN '  
              
            EXEC sp_executesql @c_SQL   
               , N'@c_PrimaryKey1 NVARCHAR(30)  OUTPUT   
                  ,@c_PrimaryKey2 NVARCHAR(30)  OUTPUT  
                  ,@c_PrimaryKey3 NVARCHAR(30)  OUTPUT'  
                  ,@c_PrimaryKey1   OUTPUT     
                  ,@c_PrimaryKey2   OUTPUT   
                  ,@c_PrimaryKey3   OUTPUT   
  
            FETCH NEXT FROM CUR_PRIMARYKEY INTO @c_ColumnName  
         END  
         CLOSE CUR_PRIMARYKEY  
         DEALLOCATE CUR_PRIMARYKEY  
     
         SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_PrimaryKey1, @c_PrimaryKey2, @c_PrimaryKey3   
                     , @x_XMLSchema, @x_XMLData  
                     , @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '        
        
         EXEC sp_executesql @c_SQL       
            , N'@c_PrimaryKey1 NVARCHAR(30)     
              , @c_PrimaryKey2 NVARCHAR(30)  
              , @c_PrimaryKey3 NVARCHAR(30)   
              , @x_XMLSchema   XML  
              , @x_XMLData     XML  
              , @b_Success     INT OUTPUT  
              , @n_Err         INT OUTPUT  
              , @c_ErrMsg      NVARCHAR(250) OUTPUT'   
            , @c_PrimaryKey1       
            , @c_PrimaryKey2     
            , @c_PrimaryKey3  
            , @x_XMLSchema  
            , @x_XMLData     
            , @b_Success   OUTPUT        
            , @n_Err       OUTPUT        
            , @c_ErrMsg    OUTPUT      
  
         IF @b_Success <> 1  
         BEGIN   
            SET @b_InValid = 1        
            GOTO QUIT_SP  
         END   
      END  
      NEXT_SP_RULE:   
      FETCH NEXT FROM CUR_CHK_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName  
   END   
   CLOSE CUR_CHK_SPCONDITION  
   DEALLOCATE CUR_CHK_SPCONDITION   
          
   QUIT_SP:  
   IF CURSOR_STATUS('LOCAL' , 'CUR_CHK_REQUIRED') in (0 , 1)  
   BEGIN  
      CLOSE CUR_CHK_REQUIRED  
      DEALLOCATE CUR_CHK_REQUIRED  
   END  
  
   IF CURSOR_STATUS('LOCAL' , 'CUR_CHK_CONDITION') in (0 , 1)  
   BEGIN  
      CLOSE CUR_CHK_CONDITION  
      DEALLOCATE CUR_CHK_CONDITION  
   END  
  
   IF CURSOR_STATUS('LOCAL' , 'CUR_CHK_SPCONDITION') in (0 , 1)  
   BEGIN  
      CLOSE CUR_CHK_SPCONDITION  
      DEALLOCATE CUR_CHK_SPCONDITION  
  END  
  
   IF @b_InValid = 1  
   BEGIN  
      SET @b_Success = 0  
   END   
       
END    

GO