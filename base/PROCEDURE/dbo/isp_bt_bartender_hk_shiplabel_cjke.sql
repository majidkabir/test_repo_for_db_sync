SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_HK_shipLabel_CJKE                                */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2017-08-11 1.0  CSCHONG    Created (WMS-2681)                              */ 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_HK_shipLabel_CJKE]                               
(  @c_Sparm1            NVARCHAR(250),                      
   @c_Sparm2            NVARCHAR(250),                      
   @c_Sparm3            NVARCHAR(250),                      
   @c_Sparm4            NVARCHAR(250),                      
   @c_Sparm5            NVARCHAR(250),                      
   @c_Sparm6            NVARCHAR(250),                      
   @c_Sparm7            NVARCHAR(250),                      
   @c_Sparm8            NVARCHAR(250),                      
   @c_Sparm9            NVARCHAR(250),                      
   @c_Sparm10           NVARCHAR(250),                
   @b_debug             INT = 0                                 
)                              
AS                              
BEGIN                              
   SET NOCOUNT ON                         
   SET ANSI_NULLS OFF                        
   SET QUOTED_IDENTIFIER OFF                         
   SET CONCAT_NULL_YIELDS_NULL OFF                        
   SET ANSI_WARNINGS OFF                              
                                      
   DECLARE            
      @n_TTLSKUCNT         INT,
      @n_TTLSKUQTY         INT, 
      @n_Page              INT,
      @n_ID                INT, 
      @n_RID               INT, 
      @n_MaxLine           INT,       
      @n_MaxLineRec        INT, 
      @c_OHCompany         NVARCHAR(45),
      @c_OHAddress         NVARCHAR(45),
      @c_OHPhone1          NVARCHAR(45),
      @c_OHZip             NVARCHAR(45),
      @c_ExtOrdkey         NVARCHAR(30),
      @c_Pickslipno        NVARCHAR(20),
      @c_GetPickslipno     NVARCHAR(20),
      @c_STNotes2          NVARCHAR(60),
      @c_PDCartonNo        NVARCHAR(10),
      @c_OHComdescr        NVARCHAR(45),
      @c_OHPhone1descr     NVARCHAR(45),
      @c_OHUDF04descr      NVARCHAR(45),
      @c_OHUDF04           NVARCHAR(45),
      @c_OHMCountry        NVARCHAR(45),
      @c_OHMState          NVARCHAR(45),
      @c_OHUDF03           NVARCHAR(45),
      @c_OHMcity           NVARCHAR(45),
      @c_OHMContact1       NVARCHAR(45),
      @n_CartonNo          INT,
      @c_OHMContact2       NVARCHAR(45),
      @c_OHccity           NVARCHAR(45),
      @c_OHbcity           NVARCHAR(45),
     -- @c_OHMcountry        NVARCHAR(45),
      @c_OHMAdd4           NVARCHAR(45),
      @c_labelno           NVARCHAR(20),
      @c_Getlabelno        NVARCHAR(20),
      @n_MAxCarton         INT,
      @c_OHDisPlace        NVARCHAR(30)
     
      
  DECLARE    
      @c_line01            NVARCHAR(80), 
      @c_SKU01             NVARCHAR(80),  
      @c_SKUDesr01         NVARCHAR(80),  
      @n_qty01             INT,         
      @c_line02            NVARCHAR(80), 
      @c_SKU02             NVARCHAR(80),
      @c_SKUDesr02         NVARCHAR(80),
      @n_qty02             INT,            
      @c_line03            NVARCHAR(80), 
      @c_SKU03             NVARCHAR(80), 
      @c_SKUDesr03         NVARCHAR(80), 
      @n_qty03             INT      
  
 Declare                           
      @c_SQL             NVARCHAR(4000),                
      @c_SQLSORT         NVARCHAR(4000),                
      @c_SQLJOIN         NVARCHAR(4000),                    
      @n_TTLpage         INT          
          
  DECLARE  @d_Trace_StartTime   DATETIME,           
           @d_Trace_EndTime    DATETIME,          
           @c_Trace_ModuleName NVARCHAR(20),           
           @d_Trace_Step1      DATETIME,           
           @c_Trace_Step1      NVARCHAR(20),          
           @c_UserName         NVARCHAR(20)            
          
   SET @d_Trace_StartTime = GETDATE()          
   SET @c_Trace_ModuleName = ''          
                
    -- SET RowNo = 0                     
    SET @c_SQL = ''                
                 
                      
--    IF OBJECT_ID('tempdb..#Result','u') IS NOT NULL        
--      DROP TABLE #Result;        
          
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
          
--      IF OBJECT_ID('tempdb..#CartonContent','u') IS NOT NULL        
--      DROP TABLE #CartonContent;        
        
     CREATE TABLE [#SKULULUContent] (                     
      [ID]                    [INT] IDENTITY(1,1) NOT NULL,
      [Pickslipno]            [NVARCHAR] (20)  NULL,
      [labelno]               [NVARCHAR] (20) NULL, 
      [labellineno]           [NVARCHAR] (10) NULL, 
      [SKU]                   [NVARCHAR] (20) NULL,                                    
      [SDESCR]                [NVARCHAR] (80) NULL,                                              
      [skuqty]                INT NULL,                             
      [Retrieve]              [NVARCHAR] (1) default 'N')               
                    
                           
      IF @b_debug=1                
      BEGIN                  
        PRINT 'start'                  
      END    
      
      SET @c_SKU01 = ''
      SET @c_SKUDesr01 = ''
      SET @n_qty01 = 0
      SET @c_SKU02 = ''
      SET @c_SKUDesr02 = ''
      SET @n_qty02 = 0
      SET @c_SKU03 = ''
      SET @c_SKUDesr03 = ''
      SET @n_qty03 = 0
                                   
          
    DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
          
     
    
    SELECT distinct o.C_Company,ISNULL(o.C_Phone1,''),(ISNULL(o.C_Address1,'') + ISNULL(o.C_Address2,'') + ISNULL(o.C_Address3,'')),
    ISNULL(o.C_Zip,''),ISNULL(ST.Notes2,''),(SUBSTRING(o.C_Company,1,LEN(o.C_Company) - LEN(RIGHT(o.C_Company, 1))) + '*'), 
    (SUBSTRING(o.C_Phone1,1,LEN(o.C_Phone1) - LEN(RIGHT(o.C_Phone1, 4))) + '****'),--7
    (substring(pd.UPC,1,4) + '-' + Substring(pd.UPC,5,4)  +'-' +  Substring(pd.UPC,9,4)), --8
    ISNULL(pd.UPC,''),ISNULL(o.m_country,''),ISNULL(o.m_state,''),ISNULL(o.Userdefine03,''),ISNULL(o.m_city,''),       --13
    ISNULL(o.m_contact1,''),pd.CartonNo,o.ExternOrderKey,ISNULL(o.M_contact2,''),ISNULL(o.c_city,''),ISNULL(o.b_city,''),
    ISNULL(o.m_address4,''),pd.LabelNo,MAX(pd.CartonNo),pd.pickslipno,o.DischargePlace
     FROM PackHeader AS ph WITH (NOLOCK) 
     JOIN PackDetail AS pd ON pd.PickSlipNo = ph.PickSlipNo 
     JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey  
     JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.storerkey  
      WHERE pd.pickslipno =@c_Sparm1  AND pd.labelno = @c_Sparm2  
     GROUP BY o.C_Company,ISNULL(o.C_Phone1,''),(ISNULL(o.C_Address1,'') + ISNULL(o.C_Address2,'') + ISNULL(o.C_Address3,'')),
    ISNULL(o.C_Zip,''),ISNULL(ST.Notes2,''),(SUBSTRING(o.C_Company,1,LEN(o.C_Company) - LEN(RIGHT(o.C_Company, 1))) + '*'), 
    (SUBSTRING(o.C_Phone1,1,LEN(o.C_Phone1) - LEN(RIGHT(o.C_Phone1, 4))) + '****'),--7
    (substring(pd.UPC,1,4) + '-' + Substring(pd.UPC,5,4)  +'-' +  Substring(pd.UPC,9,4)), 
    ISNULL(pd.UPC,''),ISNULL(o.m_country,''),ISNULL(o.m_state,''),ISNULL(o.Userdefine03,''),ISNULL(o.m_city,''),
    ISNULL(o.m_contact1,''),pd.CartonNo,o.ExternOrderKey,ISNULL(o.M_contact2,''),ISNULL(o.c_city,''),ISNULL(o.b_city,''),
    ISNULL(o.m_country,''),ISNULL(o.m_address4,''),pd.LabelNo,pd.pickslipno,o.DischargePlace
        
   OPEN CUR_StartRecLoop                    
               
   FETCH NEXT FROM CUR_StartRecLoop INTO  @c_OHCompany,@c_OHPhone1,@c_OHAddress,@c_OHZip,@c_STNotes2,@c_OHComdescr,
														@c_OHPhone1descr,@c_OHUDF04descr,@c_OHUDF04,@c_OHMCountry,
														@c_OHMState,@c_OHUDF03,@c_OHMcity ,@c_OHMContact1,@n_CartonNo,@c_ExtOrdkey,@c_OHMContact2,
														@c_OHccity,@c_OHbcity,@c_OHMAdd4,@c_labelno, @n_MAxCarton ,@c_Pickslipno ,@c_OHDisPlace    
                                                       
                 
   WHILE @@FETCH_STATUS <> -1                    
   BEGIN           
          
      IF @b_debug=1                
      BEGIN                  
        PRINT 'Cur start'                  
      END          
          
   INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                            ,Col55,Col56,Col57,Col58,Col59,Col60)             
     VALUES(@c_OHCompany,@c_OHPhone1,@c_OHAddress,@c_OHZip,@c_STNotes2,@c_OHComdescr,@c_OHPhone1descr,        --7 
            @c_OHUDF04descr,@c_OHUDF04,@c_OHMCountry,@c_OHMState,'','',       --13  
            '','','','','','','',                                             --20       
            @c_OHUDF03,@c_OHMcity ,@c_OHMContact1,@n_CartonNo,@c_ExtOrdkey,@c_OHMContact2,       --26
            @c_OHccity,@c_OHbcity,@c_OHDisPlace,@c_OHMAdd4,@c_labelno, @n_MAxCarton,'','','','','','','',   --39
            '','','','','','','','','','',''        --50   
            ,'','','','','','','','',@c_Pickslipno,'O')          
          
          
   IF @b_debug=1                
   BEGIN                
     SELECT * FROM #Result (nolock)                
   END           
            
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                      
                     
   SELECT DISTINCT col59,col31    
   FROM #Result                 
   --WHERE Col60 = 'O' 
   ORDER BY col59,col31           
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_GetPickslipno,@c_Getlabelno
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   

   INSERT INTO [#SKULULUContent] (Pickslipno,labelno,labellineno,sku,SDESCR,skuqty,Retrieve)                          
   SELECT distinct top 3 pd.pickslipno,pd.LabelNo,pd.LabelLine,pd.SKU,s.DESCR,SUM(pd.Qty),'N'
    FROM PackHeader AS ph WITH (NOLOCK) 
     JOIN PackDetail AS pd ON pd.PickSlipNo = ph.PickSlipNo 
     JOIN SKU S WITH (NOLOCK) ON s.StorerKey=pd.StorerKey AND s.sku = pd.sku
     WHERE ph.PickSlipNo=@c_GetPickslipno AND pd.LabelNo=@c_Getlabelno
     GROUP BY pd.pickslipno,pd.LabelNo,pd.LabelLine,pd.SKU,s.DESCR
     ORDER BY  pd.pickslipno,pd.LabelNo,pd.LabelLine     
                           
       IF @b_debug = '1'              
       BEGIN              
         SELECT 'sku content',* FROM #SKULULUContent          
       END                     
         
   -- SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END 

   DECLARE CUR_RowPage CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT ID
   FROM #SKULULUContent
   Order by ID

   OPEN CUR_RowPage            
            
   FETCH NEXT FROM CUR_RowPage INTO  @n_ID       
               
   WHILE @@FETCH_STATUS <> -1             
   BEGIN                 
      IF @b_debug='1'              
      BEGIN              
         SELECT * FROM #SKULULUContent
      END
      
      

      IF @n_ID = 1
      BEGIN
			SELECT @c_SKU01 = c.SKU
					,@c_SKUDesr01 = c.SDESCR    
					,@n_qty01 = c.skuqty          
			 FROM  #SKULULUContent c WITH (NOLOCK)                      
			 WHERE c.ID = 1  
       END   
       ELSE IF @n_ID = 2
       BEGIN
			SELECT @c_SKU02 = c.SKU
					,@c_SKUDesr02 = c.SDESCR    
					,@n_qty02= c.skuqty          
			 FROM  #SKULULUContent c WITH (NOLOCK)                      
			 WHERE c.ID = 2  
       END  
       ELSE IF @n_ID = 3
       BEGIN
			SELECT @c_SKU03 = c.SKU
					,@c_SKUDesr03 = c.SDESCR    
					,@n_qty03 = c.skuqty          
			 FROM  #SKULULUContent c WITH (NOLOCK)                      
			 WHERE c.ID = 3  
       END               

     FETCH NEXT FROM CUR_RowPage INTO @n_ID
     END -- While                     
      CLOSE CUR_RowPage                    
      DEALLOCATE CUR_RowPage    
               
  -- END      
  FETCH NEXT FROM CUR_RowNoLoop INTO  @c_GetPickslipno,@c_Getlabelno                
            
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop     
      	
      	
      IF @b_debug='1'              
      BEGIN              
         SELECT @c_SKU01 '@c_SKU01',@c_SKUDesr01 '@c_SKUDesr01',@n_qty02 '@n_qty02'
      END
      	
      	
   	 UPDATE #Result                    
       SET Col12 = @c_SKU01,          
           Col13 = @c_SKUDesr01,  
           Col14 = CASE WHEN @n_qty01 <> 0 THEN CONVERT(NVARCHAR(20),@n_qty01) ELSE '' END ,           
           Col15 = @c_SKU02,          
           Col16 = @c_SKUDesr02,                  
           Col17 = CASE WHEN @n_qty02 <> 0 THEN CONVERT(NVARCHAR(20),@n_qty02)  ELSE '' END,           
           Col18 = @c_SKU03,  
           Col19 = @c_SKUDesr03,
           Col20 = CASE WHEN @n_qty03 <> 0 THEN  CONVERT(NVARCHAR(20),@n_qty03) ELSE '' END
       WHERE col59 = @c_Pickslipno AND col31=@c_labelno  
       
       
       
      SET @c_SKU01 = ''
      SET @c_SKUDesr01 = ''
      SET @n_qty01 = 0
      SET @c_SKU02 = ''
      SET @c_SKUDesr02 = ''
      SET @n_qty02 = 0
      SET @c_SKU03 = ''
      SET @c_SKUDesr03 = ''
      SET @n_qty03 = 0
                                                 
             
          
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_OHCompany,@c_OHPhone1,@c_OHAddress,@c_OHZip,@c_STNotes2,@c_OHComdescr,
														@c_OHPhone1descr,@c_OHUDF04descr,@c_OHUDF04,@c_OHMCountry,
														@c_OHMState,@c_OHUDF03,@c_OHMcity ,@c_OHMContact1,@n_CartonNo,@c_ExtOrdkey,@c_OHMContact2,
														@c_OHccity,@c_OHbcity,@c_OHMAdd4,@c_labelno, @n_MAxCarton,@c_Pickslipno   ,@c_OHDisPlace                    
          
   END -- While                     
   CLOSE CUR_StartRecLoop                    
   DEALLOCATE CUR_StartRecLoop 
                      
       
   SELECT * from #result WITH (NOLOCK)  
--   WHERE LEN(ISNULL(Col21,'') +  ISNULL(Col22,'') + ISNULL(Col23,'') +                    
--         ISNULL(Col24,'') +  ISNULL(Col25,'') + ISNULL(Col26,'') +            
--         ISNULL(Col27,'') +  ISNULL(Col28,'') +  ISNULL(Col29,'') +            
--         ISNULL(Col30,'')) > 0            
          
   EXIT_SP:            
          
   SET @d_Trace_EndTime = GETDATE()          
   SET @c_UserName = SUSER_SNAME()          
             
   EXEC isp_InsertTraceInfo           
      @c_TraceCode = 'BARTENDER',          
      @c_TraceName = 'isp_BT_Bartender_HK_shipLabel_CJKE',          
      @c_starttime = @d_Trace_StartTime,          
      @c_endtime = @d_Trace_EndTime,          
      @c_step1 = @c_UserName,          
      @c_step2 = '',          
      @c_step3 = '',          
      @c_step4 = '',          
      @c_step5 = '',          
      @c_col1 = @c_Sparm1,           
      @c_col2 = @c_Sparm2,          
      @c_col3 = @c_Sparm3,          
      @c_col4 = @c_Sparm4,          
      @c_col5 = @c_Sparm5,          
      @b_Success = 1,          
      @n_Err = 0,          
      @c_ErrMsg = ''                      
           
                                    
END -- procedure   

GO