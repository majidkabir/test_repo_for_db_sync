SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_TW_DCLabel_WSN]                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-03-15 1.0  CSCHONG    Created (WMS-4242)                              */ 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_TW_DCLabel_WSN]                      
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
      @c_CSKU            NVARCHAR(30),                    
      @c_Sku             NVARCHAR(20),                         
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @n_totalcase       INT,
      @n_sequence        INT,
      @c_skugroup        NVARCHAR(10),
      @n_CPLT            INT,
      @n_CSQty           INT,
      @n_TTLPLT          INT,
      @c_ExecStatements   NVARCHAR(4000),   
      @c_ExecArguments    NVARCHAR(4000),
      @c_orderkey         NVARCHAR(20),
      @c_storerkey        NVARCHAR(20),
      @c_consigneekey     NVARCHAR(20),
      @c_col04            NVARCHAR(80),
      @c_col06            NVARCHAR(80),
      @c_col07            NVARCHAR(80),
      @c_col08            NVARCHAR(80),
      @n_ppaqty          FLOAT
          
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20)     
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''  
    SET @c_Sku = '' 
    SET @c_skugroup = ''    
    SET @n_totalcase = 0  
    SET @n_sequence  = 1 
    SET @n_CPLT = 1  
    SET @n_CSQty = 0     
    SET @n_TTLPLT = 1
              
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
     
     CREATE TABLE #TEMPCTN (
     RowID INT IDENTITY(1,1) NOT NULL, 
     Orderkey NVARCHAR(20) NULL,
     Dropid   NVARCHAR(20) NULL  
     )
              
            
  SET @c_SQLJOIN = +N' SELECT DISTINCT CONVERT(NVARCHAR(10),ORD.deliverydate,111),ORD.buyerpo,ISNULL(CS.consigneesku,''''),'''',@c_Sparm06,'       --5
             + ' '''','''','''',ORD.ExternOrderkey,ORDDET.SKU,' --10                 --(CS02)
             + ' @c_Sparm05,ORDDET.Userdefine05,'''','''','''', ' --15  
             + ' '''','''','''','''','''','     --20       
         --    + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''',ORD.Orderkey,''TW'' '   --60          
           --  + CHAR(13) +            
             + ' FROM ORDERS ORD WITH (NOLOCK)'       
             + ' JOIN OrderDetail ORDDET WITH (NOLOCK) ON ORDDET.orderkey=ORD.Orderkey'   
             + ' LEFT JOIN CONSIGNEESKU CS WITH (NOLOCK) ON CS.Sku=@c_Sparm04 AND CS.consigneekey = ORD.consigneekey'  
            -- + ' JOIN SKU S WITH (NOLOCK) ON S.Sku=ORDDET.SKU'    
             + ' WHERE ORD.Orderkey =@c_Sparm01 '   
             + ' AND ORDDET.sku = @c_Sparm04'
          
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

  SET @c_ExecArguments = N'    @c_Sparm01           NVARCHAR(80)'      
                          + ', @c_Sparm03           NVARCHAR(80)'   
                          + ', @c_Sparm04           NVARCHAR(80) '    
                          + ', @c_Sparm05           NVARCHAR(80)'  
                          + ', @c_Sparm06           NVARCHAR(80)'  
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01     
                        , @c_Sparm03
                        , @c_Sparm04
                        , @c_Sparm05  
                        , @c_Sparm06
        
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END        
   IF @b_debug=1        
   BEGIN        
      SELECT * FROM #Result (nolock)        
   END        

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                         
   SELECT DISTINCT Col03,Col10,col59 FROM #Result          
       
   OPEN CUR_RowNoLoop            
       
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_CSku,@c_sku,@c_orderkey    
         
   WHILE @@FETCH_STATUS <> -1            
   BEGIN   
    SET @n_CSQty = 0
    SET @c_storerkey = ''
    
    SELECT @c_storerkey = ORD.storerkey
          ,@c_consigneekey = ORD.ConsigneeKey
    FROM ORDERS ORD (NOLOCK) 
    WHERE ORD.OrderKey = @c_orderkey
    
    
    SELECT @n_CSQty = crossskuqty
    FROM ConsigneeSKU AS cs WITH (NOLOCK) 
    WHERE cs.consigneesku = @c_CSku
    AND cs.StorerKey=@c_storerkey
    AND cs.ConsigneeKey = @c_consigneekey
    
   IF @b_debug='1'
   BEGIN
      SELECT @n_CSQty '@n_CSQty',@c_CSku '@c_CSku',@c_storerkey '@c_storerkey', @c_consigneekey '@c_consigneekey'
   END


    IF @n_CSQty > 0
    BEGIN
      SET @c_col04 = CONVERT(NVARCHAR(10),@n_CSQty)
      --SET @c_col06 = CONVERT(NVARCHAR(10),CEILING(@c_Sparm06/@n_CSQty))
    END
    ELSE
    BEGIN
      
      SELECT @n_CSQty = P.CASECNT
      FROM SKU S WITH (NOLOCK)
      JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PACKKey
      WHERE S.storerkey = @c_storerkey
      AND S.Sku = @c_Sku
      
      SET @c_col04 = CONVERT(NVARCHAR(10),@n_CSQty)
      
    END  
    
    SET @n_ppaqty = ''
    SET @n_ppaqty = CAST(@c_Sparm06 as NUMERIC (10,2))
    
    --SELECT @n_ppaqty AS qty,(@n_ppaqty/NULLIF(@n_CSQty,0)) AS caseqty,CEILING(@n_ppaqty/NULLIF(@n_CSQty,0)) AS roundqty
    
    SET @c_col06 = CONVERT(NVARCHAR(10),CEILING(@n_ppaqty/NULLIF(@n_CSQty,0)))


    INSERT INTO #TEMPCTN
    (
      -- RowID -- this column value is auto-generated
      Orderkey,
      Dropid
    )
   SELECT DISTINCT  PD.OrderKey,PD.DropID
   FROM PICKDETAIL PD WITH (NOLOCK)
   WHERE PD.OrderKey = @c_orderkey
   AND PD.Storerkey = @c_storerkey
   ORDER BY pd.DropID
   
   
   SET @n_TTLPLT = 1
   
   SELECT @n_TTLPLT = COUNT(1)
   FROM #TEMPCTN 
   WHERE Orderkey = @c_orderkey
   
   SELECT @n_CPLT =RowID
   FROM #TEMPCTN
   WHERE Dropid = @c_Sparm02


   IF @b_debug='1'
   BEGIN
      SELECT @n_CSQty '@n_CSQty',@c_Sparm06 '@c_Sparm06'
       PRINT 'sku : ' + @c_Sku + ' with rowid : ' + convert (nvarchar(10),@n_CPLT)
   END

   UPDATE #Result
   SET Col04 = @c_col04,
       Col06 = @c_col06,
       Col07 = convert(nvarchar(10),@n_CPLT),
       Col08 = convert(nvarchar(10),@n_TTLPLT)

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_CSku,@c_sku,@c_orderkey    
   END -- While             
   CLOSE CUR_RowNoLoop            
   DEALLOCATE CUR_RowNoLoop                  
       
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_TW_DCLabel_WSN',  
      @c_starttime = @d_Trace_StartTime,  
      @c_endtime = @d_Trace_EndTime,  
      @c_step1 = @c_UserName,  
      @c_step2 = '',  
      @c_step3 = '',  
      @c_step4 = '',  
      @c_step5 = '',  
      @c_col1 = @c_Sparm01,   
      @c_col2 = @c_Sparm02,  
      @c_col3 = @c_Sparm03,  
      @c_col4 = @c_Sparm04,  
      @c_col5 = @c_Sparm05,  
      @b_Success = 1,  
      @n_Err = 0,  
      @c_ErrMsg = ''              
   
   SELECT * FROM #Result (nolock) 


DROP TABLE #TEMPCTN                                  
END -- procedure   


GO