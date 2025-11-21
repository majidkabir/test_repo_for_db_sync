SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: BarTender Print From KITTING screen                               */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */                     
/* 2019-04-22 1.0  WLCHOOI    Created - (WMS-8769)                            */             
/******************************************************************************/                    
                      
CREATE PROC [dbo].[isp_BT_Bartender_KITPLTLBL_01]                           
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

        , @c_SKU                  NVARCHAR(80) = ''
        , @n_Boxes                INT = 0
        , @n_Qty                  INT = 0
        , @c_Lottable02           NVARCHAR(80) = ''
        , @c_Lottable04           NVARCHAR(80) = ''

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
    
    --SELECT @n_Boxes = CASE WHEN P.CASECNT > 0 THEN CEILING(SUM(KT.Qty)/P.Casecnt) ELSE 0 END
    --      ,@n_Qty   = SUM(KT.Qty)
    --FROM KITDETAIL KT (NOLOCK)
    --JOIN SKU S (NOLOCK) ON S.SKU = KT.SKU AND S.STORERKEY = KT.STORERKEY
    --JOIN PACK P (NOLOCK) ON P.PACKKEY = S.PACKKEY
    --WHERE KT.KITKEY = @c_Sparm1 AND KT.TYPE = 'F'
    --GROUP BY P.Casecnt 

    CREATE TABLE #SKUBoxes
    ( SKU        NVARCHAR(80),
      Boxes      INT )
    
    /*SELECT @n_Qty   = SUM(KT.Qty)
    FROM KITDETAIL KT (NOLOCK)
    WHERE KT.KITKEY = @c_Sparm1 AND KT.TYPE = 'F'

    INSERT INTO #SKUBoxes
    SELECT DISTINCT KT.SKU, CASE WHEN P.CASECNT > 0 THEN CEILING(@n_Qty/P.Casecnt) ELSE 0 END
    FROM KITDETAIL KT (NOLOCK)
    JOIN SKU S (NOLOCK) ON S.SKU = KT.SKU AND S.STORERKEY = KT.STORERKEY
    JOIN PACK P (NOLOCK) ON P.PACKKEY = S.PACKKEY
    WHERE KT.KITKEY = @c_Sparm1 AND KT.TYPE = 'F'

    SELECT @n_Boxes = SUM(Boxes) FROM #SKUBoxes*/
    
    SET @c_SQLJOIN = N' SELECT DISTINCT ISNULL(KT.LOTTABLE06,''''), CONVERT(NVARCHAR(10),GETDATE(),111), KT.ID, ISNULL(S.DESCR,''''), KT.SKU, ' + CHAR(13) --5 
                   +  ' ISNULL(KT.LOTTABLE02,''''), '
                   +  ' CASE WHEN P.CASECNT > 0 THEN CEILING(SUM(KT.Qty)/P.Casecnt) ELSE 0 END, '
                   +  ' SUM(KT.Qty), '
                   +  ' CONVERT(NVARCHAR(10),ISNULL(KT.LOTTABLE04,''''),111) , ' + CHAR(13) --9
                   +  ' ''93'' + LTRIM(RTRIM(REPLACE(KT.SKU, ''-'', ''''))) + ''^110'' + LTRIM(RTRIM(ISNULL(KT.LOTTABLE02,'''')))  ' + CHAR(13)
                   +  ' + ''^199'' + LTRIM(RTRIM(CONVERT(NVARCHAR(10),ISNULL(KT.LOTTABLE04,''''),112))) + ''^137'' + LTRIM(RTRIM(CONVERT(NVARCHAR(10),CASE WHEN P.CASECNT > 0 THEN CEILING(SUM(KT.Qty)/P.Casecnt) ELSE 0 END))) ' --10
                   +  ' ,KT.ID,'''','''','''','''','''','''','''','''','''', ' + CHAR(13) --20
                   +  ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --30
                   +  ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --40
                   +  ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --50
                   +  ' '''','''','''','''','''','''','''','''',@c_Sparm1,''CN'' ' + CHAR(13) --60
                   +  ' FROM KITDETAIL KT (NOLOCK) ' + CHAR(13) 
                   +  ' JOIN SKU S (NOLOCK) ON S.SKU = KT.SKU AND S.STORERKEY = KT.STORERKEY' + CHAR(13) 
                   +  ' JOIN PACK P (NOLOCK) ON P.Packkey = S.Packkey ' + CHAR(13)
                   +  ' WHERE KT.KITKEY = @c_Sparm1 AND KT.TYPE = ''T'' ' 
                   +  ' AND KT.ID = CASE WHEN @c_Sparm2 = '''' THEN KT.ID ELSE @c_Sparm2 END '
                   +  ' GROUP BY ISNULL(KT.LOTTABLE06,''''), KT.ID, ISNULL(S.DESCR,''''), KT.SKU, '
                   +  ' ISNULL(KT.LOTTABLE02,''''), '
                   +  ' CONVERT(NVARCHAR(10),ISNULL(KT.LOTTABLE04,''''),111), '
                   +  ' ''93'' + LTRIM(RTRIM(REPLACE(KT.SKU, ''-'', ''''))) + ''^110'' + LTRIM(RTRIM(ISNULL(KT.LOTTABLE02,''''))) '
                   +  ' + ''^199'' + LTRIM(RTRIM(CONVERT(NVARCHAR(10),ISNULL(KT.LOTTABLE04,''''),112))) + ''^137'', '
                   +  ' P.Casecnt '


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
                          +',@n_Boxes             INT '
                          +',@n_Qty               INT '


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
                       , @n_Boxes
                       , @n_Qty

    IF @b_debug=1            
    BEGIN              
      PRINT @c_SQL              
    END  
    
    --DECLARE CUR_KT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
    --SELECT @n_Boxes = CEILING(SUM(KT.Qty)/P.Casecnt)
    --      ,@n_Qty   = SUM(KT.Qty)
    --FROM KITDETAIL KT (NOLOCK)
    --JOIN SKU S (NOLOCK) ON S.SKU = KT.SKU AND S.STORERKEY = KT.STORERKEY
    --JOIN PACK P (NOLOCK) ON P.PACKKEY = S.PACKKEY
    --WHERE KT.KITKEY = @c_Sparm1 AND KT.TYPE = 'F'

    --OPEN CUR_KT
    --FETCH NEXT FROM CUR_KT INTO @c_SKU, @c_Lottable02, @c_Lottable04
    --WHILE @@FETCH_STATUS <> -1   
    --BEGIN
    --   SELECT @n_Boxes = CEILING(SUM(KT.Qty)/P.Casecnt)
    --         ,@n_Qty   = SUM(KT.Qty)
    --   FROM KITDETAIL KT (NOLOCK)
    --   JOIN SKU S (NOLOCK) ON S.SKU = KT.SKU AND S.STORERKEY = KT.STORERKEY
    --   JOIN PACK P (NOLOCK) ON P.PACKKEY = S.PACKKEY
    --   WHERE KT.KITKEY = @c_Sparm1 AND S.SKU = @c_SKU
    --   GROUP BY P.Casecnt

    --   UPDATE #Result
    --   SET COL07 = @n_Boxes, COL08 = @n_Qty
    --      ,COL10 = '(93)' + LTRIM(RTRIM(REPLACE(@c_SKU, '-', ''))) + '(10)' + LTRIM(RTRIM(@c_Lottable02)) + '(99)' 
    --               + LTRIM(RTRIM(REPLACE(@c_Lottable04, '/', ''))) + '(37)' + CAST(@n_Boxes AS NVARCHAR(10))
    --   WHERE COL59 = @c_Sparm1 AND COL05 = @c_SKU AND COL06 = @c_Lottable02 AND COL09 = @c_Lottable04

    --FETCH NEXT FROM CUR_KT INTO @c_SKU, @c_Lottable02, @c_Lottable04
    --END    
      
    IF @b_debug = 1      
    BEGIN      
       SELECT * FROM #Result(NOLOCK)      
    END           
                          
    SELECT * FROM #Result WITH (NOLOCK)      
    ORDER BY ID    
                 
                     
EXIT_SP:        
      
   SET @d_Trace_EndTime = GETDATE()      
   SET @c_UserName = SUSER_SNAME()      
         
   EXEC isp_InsertTraceInfo       
      @c_TraceCode = 'BARTENDER',      
      @c_TraceName = 'isp_BT_Bartender_KITPLTLBL_01',      
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