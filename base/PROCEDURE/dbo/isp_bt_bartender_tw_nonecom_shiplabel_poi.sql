SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_TW_NONECOM_shipLabel_POI                         */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-02-18 1.0  CSCHONG    Created (WMS-8000)                              */ 
/* 2018-03-07 1.1  CSCHONG    WMS-8000 group by skugroup (CS01)               */
/******************************************************************************/                
						
CREATE PROC [dbo].[isp_BT_Bartender_TW_NONECOM_shipLabel_POI]                      
(  @c_Sparm01            NVARCHAR(250),              
	@c_Sparm02            NVARCHAR(250),              
	@c_Sparm03            NVARCHAR(250),              
	@c_Sparm04            NVARCHAR(250),              
	@c_Sparm05            NVARCHAR(250),              
	@c_Sparm06            NVARCHAR(250),              
	@c_Sparm07            NVARCHAR(250),              
	@c_Sparm08            NVARCHAR(250),              
	@c_Sparm09            NVARCHAR(250),              
	@c_Sparm10            NVARCHAR(250),        
	@b_debug              INT = 0                         
)                      
AS                      
BEGIN                      
	SET NOCOUNT ON                 
	SET ANSI_NULLS OFF                
	SET QUOTED_IDENTIFIER OFF                 
	SET CONCAT_NULL_YIELDS_NULL OFF                                      
										
	DECLARE                  
		@c_Uccno           NVARCHAR(20),                    
		@c_Sku             NVARCHAR(20),                         
		@n_intFlag         INT,     
		@n_CntRec          INT,    
		@c_SQL             NVARCHAR(4000),        
		@c_SQLSORT         NVARCHAR(4000),        
		@c_SQLJOIN         NVARCHAR(4000),
		@n_totalcase       INT,
		@n_sequence        INT,
		@c_skugroup        NVARCHAR(50),
		@c_combineskugrp   NVARCHAR(50),
		@c_CUDF01          NVARCHAR(50),
		@c_combineCUDF01   NVARCHAR(50),
		@c_itemcls         NVARCHAR(50),
		@c_combineitemCLS  NVARCHAR(50),
		@c_ICUDF01         NVARCHAR(50),
		@c_combineICUDF01  NVARCHAR(50),
		@n_CntSku          INT,
		@n_TTLQty          INT,
		@c_skugrpqty       INT,
		@c_delimiter       NVARCHAR(1),
		@n_RecCtn          INT,
		@n_LineCtn         INT,
		@c_labelno         NVARCHAR(20),
		@c_Pickslipno      NVARCHAR(20),
		@c_CartonNo         NVARCHAR(20)      
			 
	 
  DECLARE @d_Trace_StartTime   DATETIME,   
			  @d_Trace_EndTime    DATETIME,  
			  @c_Trace_ModuleName NVARCHAR(20),   
			  @d_Trace_Step1      DATETIME,   
			  @c_Trace_Step1      NVARCHAR(20),  
			  @c_UserName         NVARCHAR(20),
			  @c_ExecStatements  NVARCHAR(4000),    
			  @c_ExecArguments   NVARCHAR(4000)        
  
	SET @d_Trace_StartTime = GETDATE()  
	SET @c_Trace_ModuleName = ''  
		  
	 -- SET RowNo = 0             
	 SET @c_SQL = ''  
	 SET @c_Sku = '' 
	 SET @c_skugroup = ''    
	 SET @n_totalcase = 0  
	 SET @n_sequence  = 1 
	 SET @n_CntSku = 1  
	 SET @n_TTLQty = 0  
	 SET @c_delimiter = ',' 
	 SET @c_combineskugrp = ''  
	 SET @c_combineCUDF01 = ''
	 SET @n_LineCtn = 1
				  
	 CREATE TABLE [#Result] (             
		[ID]    [INT] IDENTITY(1,1) NOT NULL,                            
		[Col01] [NVARCHAR] (80) NULL,              
		[Col02] [NVARCHAR] (80) NULL,              
		[Col03] [NVARCHAR] (80) NULL,              
		[Col04] [NVARCHAR] (80) NULL,              
		[Col05] [NVARCHAR] (80) NULL,              
		[Col06] [NVARCHAR] (80) NULL,              
		[Col07] [NVARCHAR] (80) NULL,              
		[Col08] [NVARCHAR] (80) NULL,              
		[Col09] [NVARCHAR] (80) NULL,              
		[Col10] [NVARCHAR] (80) NULL,              
		[Col11] [NVARCHAR] (80) NULL,              
		[Col12] [NVARCHAR] (80) NULL,              
		[Col13] [NVARCHAR] (80) NULL,              
		[Col14] [NVARCHAR] (80) NULL,              
		[Col15] [NVARCHAR] (80) NULL,              
		[Col16] [NVARCHAR] (80) NULL,              
		[Col17] [NVARCHAR] (80) NULL,              
		[Col18] [NVARCHAR] (80) NULL,              
		[Col19] [NVARCHAR] (80) NULL,              
		[Col20] [NVARCHAR] (80) NULL,              
		[Col21] [NVARCHAR] (80) NULL,              
		[Col22] [NVARCHAR] (80) NULL,              
		[Col23] [NVARCHAR] (80) NULL,              
		[Col24] [NVARCHAR] (80) NULL,              
		[Col25] [NVARCHAR] (80) NULL,              
		[Col26] [NVARCHAR] (80) NULL,              
		[Col27] [NVARCHAR] (80) NULL,              
		[Col28] [NVARCHAR] (80) NULL,              
		[Col29] [NVARCHAR] (80) NULL,              
		[Col30] [NVARCHAR] (80) NULL,              
		[Col31] [NVARCHAR] (80) NULL,              
		[Col32] [NVARCHAR] (80) NULL,              
		[Col33] [NVARCHAR] (80) NULL,              
		[Col34] [NVARCHAR] (80) NULL,              
		[Col35] [NVARCHAR] (80) NULL,              
		[Col36] [NVARCHAR] (80) NULL,              
		[Col37] [NVARCHAR] (80) NULL,              
		[Col38] [NVARCHAR] (80) NULL,              
		[Col39] [NVARCHAR] (80) NULL,              
		[Col40] [NVARCHAR] (80) NULL,              
		[Col41] [NVARCHAR] (80) NULL,              
		[Col42] [NVARCHAR] (80) NULL,              
		[Col43] [NVARCHAR] (80) NULL,              
		[Col44] [NVARCHAR] (80) NULL,              
		[Col45] [NVARCHAR] (80) NULL,              
		[Col46] [NVARCHAR] (80) NULL,              
		[Col47] [NVARCHAR] (80) NULL,              
		[Col48] [NVARCHAR] (80) NULL,              
		[Col49] [NVARCHAR] (80) NULL,              
		[Col50] [NVARCHAR] (80) NULL,             
		[Col51] [NVARCHAR] (80) NULL,              
		[Col52] [NVARCHAR] (80) NULL,              
		[Col53] [NVARCHAR] (80) NULL,              
		[Col54] [NVARCHAR] (80) NULL,              
		[Col55] [NVARCHAR] (80) NULL,              
		[Col56] [NVARCHAR] (80) NULL,              
		[Col57] [NVARCHAR] (80) NULL,              
		[Col58] [NVARCHAR] (80) NULL,              
		[Col59] [NVARCHAR] (80) NULL,              
		[Col60] [NVARCHAR] (80) NULL             
	  )            
				  
				
  SET @c_SQLJOIN = +N' SELECT DISTINCT o.storerkey,o.orderkey,o.externorderkey,o.buyerpo,o.ordergroup,'       --5
				 + ' o.type,SSO.Route,ph.pickslipno,pd.cartonno,SUM(Pd.qty),' --10  
				 + ' ISNULL(o.c_Company,''''),o.consigneekey,ISNULL(o.C_Address1,''''),ISNULL(o.C_Address2,''''),'
				 + ' ISNULL(o.c_Address3,''''), ' --15    
				 + ' ISNULL(o.c_Address4,''''),ISNULL(o.C_contact1,''''),ISNULL(o.C_phone1,''''),ISNULL(o.C_phone2,''''),'
				 + ' CONVERT(NVARCHAR(10),o.deliverydate,111),'  --20      
			--    + CHAR(13) +      
				 --+ ' ISNULL(o.notes,''''),ISNULL(s.itemclass,''''),ISNULL(c.udf01,''''),s.skugroup,ISNULL(c1.udf01,''''),'  --CS01
				 + ' ISNULL(o.notes,''''),'''','''','''','''','--ISNULL(s.itemclass,''''),ISNULL(c.udf01,''''),'''','''','    --CS01
				 + ' REPLICATE(''0'',3-LEN(CARTONNO))+ RTRIM(CAST(CARTONNO AS NVARCHAR(10))) ,'''','''','''','''','  --30  
				 + ' '''','''','''','''','''','''','''','''','''','''','   --40       
				 + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
				 + ' '''','''','''','''','''','''','''','''','''',pd.labelno '   --60          
			  --  + CHAR(13) +            
				 + ' FROM PackHeader AS ph WITH (NOLOCK)'       
				 + ' JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'   
				 + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '    
				 + ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = pd.storerkey AND S.sku = pd.sku '
				 + ' LEFT JOIN StorerSODefault SSO WITH (NOLOCK) ON SSO.storerkey=O.consigneekey '
				-- + ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON c.listname = ''ITEMCLASS'' and C.Code=s.itemclass and C.storerkey = O.storerkey'  
			     --+ ' LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = ''SKUGroup'' and C1.Code=s.skugroup and C1.storerkey = O.storerkey'   
				 + ' WHERE pd.pickslipno = @c_Sparm01 '   
				 + ' AND pd.labelno = @c_Sparm02 '    
				 + ' GROUP BY o.storerkey,o.orderkey,o.externorderkey,o.buyerpo,o.ordergroup,o.type,SSO.Route,ph.pickslipno,pd.cartonno,'  
				 + ' ISNULL(o.c_Company,''''),o.consigneekey,ISNULL(o.C_Address1,''''),ISNULL(o.C_Address2,''''),ISNULL(o.c_Address3,''''),'   
				 + 'ISNULL(o.c_Address4,''''),ISNULL(o.C_contact1,''''),ISNULL(o.C_phone1,''''),ISNULL(o.C_phone2,''''),' 
			    -- + ' CONVERT(NVARCHAR(10),o.deliverydate,111),ISNULL(o.notes,''''),ISNULL(s.itemclass,''''),ISNULL(c.udf01,''''),s.skugroup,c1.udf01, '     --CS01
				 + ' CONVERT(NVARCHAR(10),o.deliverydate,111),ISNULL(o.notes,''''),'--ISNULL(s.itemclass,''''),ISNULL(c.udf01,''''), '     --CS01
				 + ' REPLICATE(''0'',3-LEN(CARTONNO))+ RTRIM(CAST(CARTONNO AS NVARCHAR(10))),pd.labelno '    

IF @b_debug=1        
BEGIN        
	SELECT @c_SQLJOIN          
END                
				  
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
				 +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
				 +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
				 +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
				 +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
				 + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
	 
SET @c_SQL = @c_SQL + @c_SQLJOIN        
		  
--EXEC sp_executesql @c_SQL          

 SET @c_ExecArguments = N'@c_Sparm01      NVARCHAR(80)'    
					 + ', @c_Sparm02      NVARCHAR(80) '
							
  
	EXEC sp_ExecuteSql    @c_SQL     
						, @c_ExecArguments    
						, @c_Sparm01    
						, @c_Sparm02   							   
		  
	IF @b_debug=1        
	BEGIN          
		PRINT @c_SQL          
	END        
	IF @b_debug=1        
	BEGIN        
	 SELECT @c_Sparm01 '@c_Sparm01',@c_Sparm02 '@c_Sparm01'
	 SELECT * FROM #Result (nolock)        
	END     
	
	set @c_skugrpqty = 0 

    --SET @c_skugroup = ''
	
	 
   
   SET @n_RecCtn = 1

   SELECT @n_RecCtn =  count(distinct c1.udf01)
   from packdetail pd (nolock)
   join sku s (nolock) on s.storerkey = pd.storerkey and s.sku=pd.sku
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'SKUGroup' and C1.Code=s.skugroup and C1.storerkey = pd.storerkey
   where pd.pickslipno = @c_Sparm01
   and pd.labelno =@c_Sparm02

   SET @n_LineCtn = @n_RecCtn

    DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    select distinct  RTRIM(s.skugroup),
	                 RTRIM(c1.udf01)
    from packdetail pd (nolock)
    join sku s (nolock) on s.storerkey = pd.storerkey and s.sku=pd.sku
    LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'SKUGroup' and C1.Code=s.skugroup and C1.storerkey = pd.storerkey
    where pd.pickslipno =@c_Sparm01
    and pd.labelno =@c_Sparm02
	 group by  RTRIM(s.skugroup), RTRIM(c1.udf01)
	order by  RTRIM(s.skugroup)   
          
   OPEN CUR_RowNoLoop                  
             
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_skugroup,@c_CUDF01    
               
   WHILE @@FETCH_STATUS <> -1             
   BEGIN  
	

	IF @n_RecCtn = 1 AND @c_combineskugrp = ''
	BEGIN
	  SET @c_combineskugrp = @c_skugroup --+ @c_delimiter 
	  SET @c_combineCUdf01 = @c_CUDF01 --+ @c_delimiter 
	END

	--SET @n_LineCtn = @n_RecCtn
	
   IF @n_RecCtn > 1 
   BEGIN
     IF @n_LineCtn > 1
      BEGIN
       SET @c_combineskugrp = @c_combineskugrp + @c_skugroup + @c_delimiter 
	   SET @c_combineCUdf01 = @c_combineCUdf01 + @c_CUDF01 + @c_delimiter 
      END
      ELSE IF @n_LineCtn = 1 
      BEGIN
        SET @c_combineskugrp = @c_combineskugrp + @c_skugroup
	    SET @c_combineCUdf01 = @c_combineCUdf01 + @c_CUDF01
      END
   END
   
  -- SET @n_RecCtn = @n_RecCtn -1 
  SET @n_LineCtn = @n_LineCtn - 1


   FETCH NEXT FROM CUR_RowNoLoop INTO @c_skugroup,@c_CUDF01          
        
      END -- While                   
      CLOSE CUR_RowNoLoop                  
      DEALLOCATE CUR_RowNoLoop  
	  
	  
	  SET @n_RecCtn = 1
	  SET @n_LineCtn = 1
	  SET @c_combineitemCLS = ''

   SELECT @n_RecCtn =  count(distinct c.udf01)
   from packdetail pd (nolock)
   join sku s (nolock) on s.storerkey = pd.storerkey and s.sku=pd.sku
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON c.listname = 'ITEMCLASS' and C.Code=s.itemclass and C.storerkey = pd.storerkey
   where pd.pickslipno = @c_Sparm01
   and pd.labelno =@c_Sparm02

   SET @n_LineCtn = @n_RecCtn

    DECLARE CUR_ItemClassLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    select distinct RTRIM(s.itemclass),
					RTRIM(C.udf01)
    from packdetail pd (nolock)
    join sku s (nolock) on s.storerkey = pd.storerkey and s.sku=pd.sku
	LEFT JOIN CODELKUP C WITH (NOLOCK) ON c.listname = 'ITEMCLASS' and C.Code=s.itemclass and C.storerkey = pd.storerkey
    where pd.pickslipno =@c_Sparm01
    and pd.labelno =@c_Sparm02
	 group by  RTRIM(s.itemclass),
		   	   RTRIM(C.udf01)
	order by  RTRIM(s.itemclass)  
          
   OPEN CUR_ItemClassLoop                  
             
   FETCH NEXT FROM CUR_ItemClassLoop INTO @c_itemcls,@c_ICUDF01    
               
   WHILE @@FETCH_STATUS <> -1             
   BEGIN  
	

	IF @n_RecCtn = 1 AND @c_combineitemCLS = ''
	BEGIN
	  SET @c_combineitemCLS = @c_itemcls --+ @c_delimiter 
	  SET @c_combineICUDF01 = @c_ICUDF01 --+ @c_delimiter 
	END

   IF @n_RecCtn > 1 
   BEGIN
     IF @n_LineCtn > 1
      BEGIN
        SET @c_combineitemCLS = @c_combineitemCLS + @c_itemcls + @c_delimiter 
	    SET @c_combineICUDF01 = @c_combineICUDF01 + @c_ICUDF01 + @c_delimiter  
      END
      ELSE --IF @n_LineCtn = 1 
      BEGIN
       SET @c_combineitemCLS = @c_combineitemCLS + @c_itemcls 
	   SET @c_combineICUDF01 = @c_combineICUDF01 + @c_ICUDF01 
      END

      --SET @n_LineCtn = @n_LineCtn - 1
   END
   
   SET @n_LineCtn = @n_LineCtn - 1 

   FETCH NEXT FROM CUR_ItemClassLoop INTO @c_itemcls,@c_ICUDF01         
        
      END -- While                   
      CLOSE CUR_ItemClassLoop                  
      DEALLOCATE CUR_ItemClassLoop   

   Update   #Result
   SET Col22 = @c_combineitemCLS
      ,Col23 = @c_combineICUDF01
      ,col24 = @c_combineskugrp
      ,col25 = @c_combineCUdf01
   WHERE col08 = @c_Sparm01
   and col60 =@c_Sparm02	           
		
    		 
				
EXIT_SP:    
  
	SET @d_Trace_EndTime = GETDATE()  
	SET @c_UserName = SUSER_SNAME()  
	  
	SELECT * FROM #Result (nolock) 
											 
END -- procedure   



GO