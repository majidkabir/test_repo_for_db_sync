SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/                     
/* Copyright: MAERSK  https://maersk-tools.atlassian.net/browse/UWP-9063        */                     
/* Purpose: isp_BT_Bartender_TUR_Ship_Label_Logi_TE                                  */                     
/*                                                                              */                     
/* Modifications log:                                                           */                     
/*                                                                              */                     
/* Date        Rev  Author     Purposes                                         */                     
/* 03-Oct-2023 1.0  SK		    Created											*/
/********************************************************************************/                    
CREATE   PROC [BI].[isp_BT_Bartender_TUR_Ship_Label_Logi_TE]                          
(  @c_Sparm01            NVARCHAR(250),                  
   @c_Sparm02            NVARCHAR(250)                           
)                          
AS                          
BEGIN                          
   SET NOCOUNT ON                     
   SET ANSI_NULLS OFF                    
   SET QUOTED_IDENTIFIER OFF                     
   SET CONCAT_NULL_YIELDS_NULL OFF  
	DECLARE                      
	  @c_SQL             NVARCHAR(MAX),                        
	  @c_SQLJOIN         NVARCHAR(MAX),    
	  @c_ExecStatements  NVARCHAR(MAX),           
	  @c_ExecArguments   NVARCHAR(MAX), 
	  @c_GetOrderkey     NVARCHAR(10), 
     @b_debug           INT = 0,                             
	  @n_PackSize        INT

	SET @c_SQL = N'';
	SET @n_PackSize = 0;
	-- Temp Table
	CREATE TABLE [#TestResult] (                 
	  [RNo]				[INT] NOT NULL,                                
	  [Title]			[NVARCHAR] (80) NULL,                  
	  [wh_name]			[NVARCHAR] (80) NULL,                  
	  [ship_month]		[NVARCHAR] (80) NULL,                  
	  [wh_addr]			[NVARCHAR] (MAX) NULL,                  
	  [cust_name]		[NVARCHAR] (80) NULL,                  
	  [cust_addr]		[NVARCHAR] (MAX) NULL,                  
	  [Desp_note_no]	[NVARCHAR] (80) NULL,                  
	  [TEC_part_no]		[NVARCHAR] (80) NULL,                  
	  [Cust_part_no]	[NVARCHAR] (80) NULL,                  
	  [Qty]				[NVARCHAR] (80) NULL,                  
	  [Batch]			[NVARCHAR] (80) NULL,                  
	  [Pickslipno]		[NVARCHAR] (80) NULL,                  
	  [DropID]			[NVARCHAR] (80) NULL,
	  [CaseCnt]			[NVARCHAR] (80) NULL    
	 )  
	-- Check picked Order exists
	SELECT TOP 1 @c_GetOrderkey = O.Orderkey  
	FROM 
		BI.V_PICKHEADER PH WITH (NOLOCK)   
	JOIN 
		BI.V_PICKDETAIL PD WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey 
	JOIN 
		BI.V_ORDERS O WITH (NOLOCK) ON O.ORDERKEY = PH.ORDERKEY AND O.StorerKey = PD.Storerkey  
	WHERE 
		PH.PickHeaderKey = @c_Sparm01
	AND PD.Status = '5'
	-- 
	IF ISNULL(@c_GetOrderkey,'') = ''    
	BEGIN    
		 GOTO QUIT_SP    
	END    
    -- Fetch label for the orders records picked 
   SET @c_SQLJOIN =  N' SELECT ' + CHAR(13)  
					+ N'	ROW_NUMBER() over(order by PD.Pickslipno , PD.DropID ) as RNo ' + CHAR(13) 
					+ N'	, ''TE Connectivity India Pvt LTD'' as Title ' + CHAR(13)
					+ N'	, CONCAT(F.Facility, ''-'', F.Descr) AS wh_name ' + CHAR(13) 
					+ N'    , UPPER(FORMAT(PD.EditDate, ''MMM'')) AS ship_month ' + CHAR(13)  
					+ N'	, CONCAT(  ' + CHAR(13) 
					+ N'		IIF(ISNULL(F.Address1, '''') = '''', '''', ISNULL(F.Address1, ''''))  ' + CHAR(13) 
					+ N'		, IIF(ISNULL(F.Address2, '''') = '''', '''', '','' + ISNULL(F.Address2, ''''))  ' + CHAR(13) 
					+ N'		, IIF(ISNULL(F.Address3, '''') = '''', '''', ISNULL(F.Address3, ''''))  ' + CHAR(13) 
					+ N'		, IIF(ISNULL(F.Address4, '''') = '''', '''', '','' + ISNULL(F.Address4, ''''))  ' + CHAR(13) 
					+ N'		, IIF(ISNULL(F.City, '''') = '''', '''', ISNULL(F.City, ''''))  ' + CHAR(13) 
					+ N'		, IIF(ISNULL(F.State, '''') = '''', '''', '','' + ISNULL(F.State, ''''))  ' + CHAR(13) 
					+ N'		, IIF(ISNULL(F.Country, '''') = '''', '''', ISNULL(F.Country, ''''))  ' + CHAR(13) 
					+ N'		, IIF(ISNULL(F.Zip, '''') = '''', '''', '','' + ISNULL(F.Zip, ''''))  ' + CHAR(13) 
					+ N'	) AS wh_addr  ' + CHAR(13) 
					+ N'    , S.Company AS cust_name ' + CHAR(13)  
					+ N'	, CONCAT(  ' + CHAR(13)
					+ N'		 IIF(ISNULL(O.C_Address1, '''') = '''', '''', ISNULL(O.C_Address1, ''''))  ' + CHAR(13)
					+ N'	   , IIF(ISNULL(O.C_Address2, '''') = '''', '''', '','' + ISNULL(O.C_Address2, ''''))  ' + CHAR(13)
					+ N'	   , IIF(ISNULL(O.C_Address3, '''') = '''', '''', ISNULL(O.C_Address3, ''''))  ' + CHAR(13)
					+ N'	   , IIF(ISNULL(O.C_Address4, '''') = '''', '''', '','' + ISNULL(O.C_Address4, ''''))  ' + CHAR(13)
					+ N'	   , IIF(ISNULL(O.C_City, '''') = '''', '''', ISNULL(O.C_City, ''''))  ' + CHAR(13)
					+ N'	   , IIF(ISNULL(O.C_State, '''') = '''', '''', '','' + ISNULL(O.C_State, ''''))  ' + CHAR(13)
					+ N'	   , IIF(ISNULL(O.C_Country, '''') = '''', '''', ISNULL(O.C_Country, ''''))  ' + CHAR(13)
					+ N'	   , IIF(ISNULL(O.C_Zip, '''') = '''', '''', '','' + ISNULL(O.C_Zip, ''''))  ' + CHAR(13)
					+ N'	) AS cust_addr  ' + CHAR(13)
					+ N'	, O.ExternOrderKey AS Desp_note_no  ' + CHAR(13)
					+ N'	, C.UDF03 AS TEC_part_no ' + CHAR(13)
					+ N'	, ISNULL(PD.Sku,'''') As Cust_part_no ' + CHAR(13)
					+ N'	, PD.Qty ,LA.Lottable01 AS Batch ' + CHAR(13)
					+ N'	, PD.Pickslipno , PD.DropID , P.Casecnt ' + CHAR(13)			
					+ N' FROM BI.V_PICKDETAIL PD (NOLOCK)   ' + CHAR(13)  
					+ N' JOIN BI.V_PickHeader PH (NOLOCK) ON PD.OrderKey = PH.OrderKey ' + CHAR(13)  
					+ N' JOIN BI.V_ORDERS O (NOLOCK) ON PH.ORDERKEY = O.ORDERKEY ' + CHAR(13)
					+ N' JOIN BI.V_LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot ' + CHAR(13) 
					+ N' LEFT JOIN BI.V_CODELKUP C (NOLOCK) ON PD.Sku = C.UDF02 AND PD.StorerKey = C.Storerkey AND O.ConsigneeKey = C.UDF01 ' + CHAR(13)   --WL01
					+ N' JOIN BI.V_FACILITY F (NOLOCK) ON O.Facility = F.Facility ' + CHAR(13)  
					+ N' LEFT JOIN BI.V_STORER S (NOLOCK) ON O.ConsigneeKey = S.StorerKey ' + CHAR(13) 
					+ N' JOIN BI.V_SKU SKU (NOLOCK) ON SKU.Storerkey = PD.Storerkey AND SKU.SKU = PD.SKU ' + CHAR(13)   
					+ N' JOIN BI.V_PACK P (NOLOCK) ON P.Packkey = SKU.Packkey ' + CHAR(13) 
					+ N' WHERE PD.Status = ''5'' ' + CHAR(13) 
					+ N' AND PH.PickHeaderKey = ''' + @c_Sparm01 + ''' '+ CHAR(13) 
					+ N' AND PD.DropID like ''' + @c_Sparm02 + ''' ' + CHAR(13)
	-- 
	IF @b_debug=1            
	BEGIN            
	  PRINT @c_SQLJOIN              
	END                    
	-- Insert into Temp Table
	SET @c_SQL= N' INSERT INTO #TestResult (RNo ,Title ,wh_name ,ship_month ,wh_addr ,cust_name ,cust_addr ,Desp_note_no ,TEC_part_no ,Cust_part_no ,Qty ,Batch ,Pickslipno ,DropID ,CaseCnt) '      
	SET @c_SQL = @c_SQL + @c_SQLJOIN;                 
	--Execute the SQL Query                                   
	EXEC sp_ExecuteSql   @c_SQL         
	-- 
	IF @b_debug=1            
	BEGIN              
	  PRINT @c_SQL              
	END          
QUIT_SP:    
   -- Final Result
   SELECT 
		RNo ,Title ,wh_name ,ship_month ,wh_addr ,cust_name ,cust_addr
		,Desp_note_no ,TEC_part_no ,Cust_part_no ,Qty ,Batch ,Pickslipno ,DropID, CaseCnt
	 FROM(
	       SELECT *
	       FROM #TestResult R (NOLOCK)  
	       OUTER APPLY (
		   SELECT TOP((R.Qty + (CASE WHEN ISNUMERIC(R.CaseCnt) = 1 THEN CONVERT(INT, R.CaseCnt) ELSE 0 END) - 1 ) / (CASE WHEN ISNUMERIC(R.CaseCnt) = 1 THEN CONVERT(INT, R.CaseCnt) ELSE 0 END)) (CASE WHEN ISNUMERIC(R.CaseCnt) = 1 THEN CONVERT(INT, R.CaseCnt) ELSE 0 END) [Final_QTy] FROM syscolumns) X
	  ) ret
END -- procedure

GO