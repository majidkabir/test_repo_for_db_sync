SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: BarTender Filter by ShipperKey                                    */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */                     
/* 2019-04-15 1.0  WLCHOOI    Created - (WMS-8627)                            */     
/* 2019-12-27 1.1  WLChooi    WMS-11507 - Update Loadplan.UserDefine01 = Y if */
/*                            printed before (WL01)                           */    
/* 2022-05-27 1.2  Mingle     Modify col09 logic - (WMS-19727) (ML01)         */
/* 2022-10-14 1.3  Mingle     Add new col12 - (WMS-20998) (ML02)              */
/******************************************************************************/                    
                    
CREATE PROC [dbo].[isp_BT_Bartender_PickLabel_02]                           
(  @c_Sparm1            NVARCHAR(250),                  
   @c_Sparm2            NVARCHAR(250),                  
   @c_Sparm3            NVARCHAR(250),     
   @c_Sparm4            NVARCHAR(250)='',      
   @c_Sparm5            NVARCHAR(250)='',        
   @c_Sparm6            NVARCHAR(250)='',      
   @c_Sparm7            NVARCHAR(250)='',     
   @c_Sparm8            NVARCHAR(250)='',      
   @c_Sparm9            NVARCHAR(250)='',     
   @c_Sparm10           NVARCHAR(250)='',                    
   @b_debug             INT = 0                             
)                          
AS                          
BEGIN                          
   SET NOCOUNT ON                     
   SET ANSI_NULLS OFF                    
   SET QUOTED_IDENTIFIER OFF                     
   SET CONCAT_NULL_YIELDS_NULL OFF                                  
                                  
  DECLARE @d_Trace_StartTime      DATETIME,       
           @d_Trace_EndTime       DATETIME,      
           @c_Trace_ModuleName    NVARCHAR(20),       
           @d_Trace_Step1         DATETIME,       
           @c_Trace_Step1         NVARCHAR(20),   
           @c_UserName            NVARCHAR(20)
           
  DECLARE @c_ExecStatements       NVARCHAR(MAX) = ''      
        , @c_ExecArguments        NVARCHAR(MAX) = ''      
        , @c_ExecStatements2      NVARCHAR(MAX) = ''      
        , @c_ExecStatementsAll    NVARCHAR(MAX) = ''        
        , @n_continue             INT = 1
        , @c_SQL                  NVARCHAR(4000) = ''     
        , @c_SQLJOIN              NVARCHAR(4000) = ''    
        
        , @c_COL08                NVARCHAR(60)   = ''
        , @c_COL09                NVARCHAR(60)   = ''        
        , @c_LoadLineNumber       NVARCHAR(60)   = '' 

        , @c_LPUserDefine01       NVARCHAR(10)   = ''   --WL01
		  , @c_SCData					 NVARCHAR(30)   = ''   --ML02
		  , @c_sku						 NVARCHAR(20)   = ''	  --ML02
      
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_Trace_ModuleName = ''      
                     
    CREATE TABLE [#Result]      
    (      
     [ID]        [INT] IDENTITY(1, 1) NOT NULL,      
     [Col01]     [NVARCHAR] (80) NULL,      
     [Col02]     [NVARCHAR] (80) NULL,      
     [Col03]     [NVARCHAR] (80) NULL,      
     [Col04]     [NVARCHAR] (80) NULL,      
     [Col05]     [NVARCHAR] (80) NULL,      
     [Col06]     [NVARCHAR] (80) NULL,      
     [Col07]     [NVARCHAR] (80) NULL,      
     [Col08]     [NVARCHAR] (80) NULL,      
     [Col09]     [NVARCHAR] (80) NULL,      
     [Col10]     [NVARCHAR] (80) NULL,      
     [Col11]     [NVARCHAR] (80) NULL,      
     [Col12]     [NVARCHAR] (80) NULL,      
     [Col13]     [NVARCHAR] (80) NULL,      
     [Col14]     [NVARCHAR] (80) NULL,      
     [Col15]     [NVARCHAR] (80) NULL,      
     [Col16]     [NVARCHAR] (80) NULL,      
     [Col17]     [NVARCHAR] (80) NULL,      
     [Col18]     [NVARCHAR] (80) NULL,      
     [Col19]     [NVARCHAR] (80) NULL,      
     [Col20]     [NVARCHAR] (80) NULL,      
     [Col21]     [NVARCHAR] (80) NULL,      
     [Col22]     [NVARCHAR] (80) NULL,      
     [Col23]     [NVARCHAR] (80) NULL,      
     [Col24]     [NVARCHAR] (80) NULL,      
     [Col25]     [NVARCHAR] (80) NULL,      
     [Col26]     [NVARCHAR] (80) NULL,      
     [Col27]     [NVARCHAR] (80) NULL,      
     [Col28]     [NVARCHAR] (80) NULL,      
     [Col29]     [NVARCHAR] (80) NULL,      
     [Col30]     [NVARCHAR] (80) NULL,      
     [Col31]     [NVARCHAR] (80) NULL,      
     [Col32]     [NVARCHAR] (80) NULL,      
     [Col33]     [NVARCHAR] (80) NULL,      
     [Col34]     [NVARCHAR] (80) NULL,      
     [Col35]     [NVARCHAR] (80) NULL,      
     [Col36]     [NVARCHAR] (80) NULL,      
     [Col37]     [NVARCHAR] (80) NULL,      
     [Col38]     [NVARCHAR] (80) NULL,      
     [Col39]     [NVARCHAR] (80) NULL,      
     [Col40]     [NVARCHAR] (80) NULL,      
     [Col41]     [NVARCHAR] (80) NULL,      
     [Col42]     [NVARCHAR] (80) NULL,      
     [Col43]     [NVARCHAR] (80) NULL,      
     [Col44]     [NVARCHAR] (80) NULL,      
     [Col45]     [NVARCHAR] (80) NULL,      
     [Col46]     [NVARCHAR] (80) NULL,      
     [Col47]     [NVARCHAR] (80) NULL,      
     [Col48]     [NVARCHAR] (80) NULL,      
     [Col49]     [NVARCHAR] (80) NULL,      
     [Col50]     [NVARCHAR] (80) NULL,      
     [Col51]     [NVARCHAR] (80) NULL,      
     [Col52]     [NVARCHAR] (80) NULL,      
     [Col53]     [NVARCHAR] (80) NULL,      
     [Col54]     [NVARCHAR] (80) NULL,      
     [Col55]     [NVARCHAR] (80) NULL,      
     [Col56]     [NVARCHAR] (80) NULL,      
     [Col57]     [NVARCHAR] (80) NULL,      
     [Col58]     [NVARCHAR] (80) NULL,      
     [Col59]     [NVARCHAR] (80) NULL,      
     [Col60]     [NVARCHAR] (80) NULL      
    )                
    
    --WL01 Start
    SELECT @c_LPUserDefine01 = ISNULL(LP.UserDefine01,'')
    FROM LOADPLAN LP (NOLOCK) 
    WHERE LP.Loadkey = @c_Sparm5
    --WL01 End

    SELECT @c_COL08 = CASE WHEN LTRIM(RTRIM(ISNULL(ORD.ECOM_SINGLE_FLAG,''))) = 'S' THEN N'单' ELSE N'多' END
         , @c_COL09 = CASE WHEN LTRIM(RTRIM(ISNULL(ORD.UserDefine03,''))) = '1' THEN 'W' ELSE ORD.USERDEFINE03 END	--ML01
    FROM ORDERS ORD (NOLOCK)
    WHERE ORDERKEY = @c_Sparm2

    SELECT @c_LoadLineNumber = CAST(LoadLineNumber AS INT)
    FROM LOADPLANDETAIL (NOLOCK)
    WHERE ORDERKEY = @c_Sparm2
	 



    SET @c_SQLJOIN = N' SELECT @c_Sparm1,@c_Sparm1,@c_Sparm10,@c_Sparm4,@c_Sparm3, ' + CHAR(13) --5 
                   +  ' @c_Sparm2,@c_LoadLineNumber,@c_COL08,@c_COL09,@c_Sparm5, ' + CHAR(13) --10
                   +  ' @c_Sparm2,'''','''','''','''','''','''','''','''','''', ' + CHAR(13) --20	--ML02
                   +  ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --30
                   +  ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --40
                   +  ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --50
                   +  ' '''','''','''','''','''','''','''','''',@c_Sparm2,''CN'' ' + CHAR(13) --60

    
    IF @b_debug=1            
    BEGIN 
      PRINT @c_SQLJOIN
    END
                    
    SET @c_SQL= 'INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +               
              + ',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +               
              + ',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +               
              + ',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +               
              + ',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +               
              + ',Col55,Col56,Col57,Col58,Col59,Col60) '    

    SET @c_ExecStatements = @c_SQL + CHAR(13) + @c_SQLJOIN  
    
    IF @b_debug=1            
    BEGIN            
      SELECT @c_ExecStatements              
    END 

    SET @c_ExecArguments = N'@c_Sparm1            NVARCHAR(60)'      
                          +',@c_Sparm2            NVARCHAR(60)'   
                          +',@c_Sparm3            NVARCHAR(60)' 
                          +',@c_Sparm4            NVARCHAR(60)' 
                          +',@c_Sparm5            NVARCHAR(60)' 
                          +',@c_Sparm6            NVARCHAR(60)' 
                          +',@c_Sparm7            NVARCHAR(60)' 
                          +',@c_Sparm8            NVARCHAR(60)' 
                          +',@c_Sparm9            NVARCHAR(60)' 
                          +',@c_Sparm10           NVARCHAR(60)' 
                          +',@c_COL08             NVARCHAR(60)' 
                          +',@c_COL09             NVARCHAR(60)'
                          +',@c_LoadLineNumber    NVARCHAR(60)' 
								

    EXEC sp_ExecuteSql   @c_ExecStatements       
                       , @c_ExecArguments      
                       , @c_Sparm1      
                       , @c_Sparm2 
                       , @c_Sparm3      
                       , @c_Sparm4
                       , @c_Sparm5      
                       , @c_Sparm6
                       , @c_Sparm7      
                       , @c_Sparm8
                       , @c_Sparm9
                       , @c_Sparm10
                       , @c_COL08
                       , @c_COL09  
                       , @c_LoadLineNumber
							 

    IF @b_debug=1            
    BEGIN              
      PRINT @c_SQL              
    END  
    
      
   IF @b_debug = 1      
   BEGIN      
       SELECT * FROM #Result(NOLOCK)      
   END    
	
	 --START ML02
	DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	SELECT DISTINCT sku.sku,SC.Data
	FROM SKU (NOLOCK)    
	JOIN ORDERDETAIL OD (NOLOCK) ON SKU.Storerkey = OD.Storerkey AND SKU.Sku = OD.Sku       
	JOIN ORDERS O (NOLOCK) ON OD.Orderkey = O.Orderkey      
	JOIN SKUCONFIG SC (NOLOCK) ON SC.SKU = SKU.Sku AND SC.StorerKey = SKU.StorerKey AND SC.ConfigType = 'CNY' 
	WHERE O.ORDERKEY = @c_Sparm2


	OPEN CUR_SKU		

   FETCH NEXT FROM CUR_SKU INTO @c_sku,@c_SCData
   WHILE @@FETCH_STATUS <> -1
   BEGIN       

		 UPDATE #Result  
		 SET col12 =  @c_SCData 
		 WHERE col05 = @c_sku

  
   FETCH NEXT FROM CUR_SKU INTO @c_sku,@c_SCData
	END

   CLOSE CUR_SKU
   DEALLOCATE CUR_SKU 
	--END ML02

                          
           
    SELECT * FROM #Result WITH (NOLOCK)      
    ORDER BY ID    
                 
                     
EXIT_SP:        
   --WL01 Start
   IF @c_LPUserDefine01 <> 'Y'
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT 'Update'
      END

      UPDATE LOADPLAN WITH (ROWLOCK)
      SET UserDefine01 = 'Y'
      WHERE Loadkey = @c_Sparm5
   END
   --WL01 End   

   SET @d_Trace_EndTime = GETDATE()      
   SET @c_UserName = SUSER_SNAME()      
         
   EXEC isp_InsertTraceInfo       
      @c_TraceCode = 'BARTENDER',      
      @c_TraceName = 'isp_BT_Bartender_PickLabel_02',      
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