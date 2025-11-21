SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_PALLETLBL_SG_THGBT                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-07-21 1.0  CSCHONG    Created (WMS-14319)                             */            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_PALLETLBL_SG_THGBT]                      
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
   @b_debug             INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                                  
                              
   DECLARE                  
            @c_ReceiptKey        NVARCHAR(10),                    
            @c_ExternOrderKey    NVARCHAR(10),              
            @c_Deliverydate      DATETIME,              
            @n_intFlag           INT,     
            @n_CntRec            INT,    
            @c_SQL               NVARCHAR(4000),        
            @c_SQLSORT           NVARCHAR(4000),        
            @c_SQLJOIN           NVARCHAR(4000)      
    
  DECLARE @d_Trace_StartTime    DATETIME,   
           @d_Trace_EndTime     DATETIME,  
           @c_Trace_ModuleName  NVARCHAR(20),   
           @d_Trace_Step1       DATETIME,   
           @c_Trace_Step1       NVARCHAR(20),  
           @c_UserName          NVARCHAR(20),
           @n_cntsku            INT,
           @c_mode              NVARCHAR(1),
           @c_sku               NVARCHAR(20), 
           @c_condition         NVARCHAR(150) ,
           @c_GroupBy           NVARCHAR(4000),
           @c_ExecStatements    NVARCHAR(4000),   
           @c_ExecArguments     NVARCHAR(4000),
           @c_RDTOID            NVARCHAR(20),
           @c_Putawayzone       NVARCHAR(30),
           @c_LocAisle          NVARCHAR(30)
               
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''   
    SET @c_mode = '0'             
              
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
     
     
     CREATE TABLE [#UCCTResult] ( 
      Uccno    NVARCHAR(20) NULL,
      SKU      NVARCHAR(20) NULL)
     
 
     SET @c_condition = ''
     SET @c_GroupBy = ''

    SET @c_GroupBy = ' GROUP BY RECDET.SKU,substring(S.descr,1,80),CONVERT(NVARCHAR(80),RECDET.Lottable04,103),RECDET.Lottable02,'
                    +' RECDET.Lottable01,RECDET.toid,'
                    + ' RECDET.Receiptkey'
             
    SET @c_SQLJOIN = +' SELECT DISTINCT RECDET.SKU,substring(S.descr,1,80),CONVERT(NVARCHAR(80),RECDET.Lottable04,103),RECDET.Lottable02,'+ CHAR(13)
             + ' RECDET.Lottable01,'                      --5   
             + ' SUM(RECDET.QtyReceived),RECDET.toid,'''','
             + ' '''' ,'''', '      --10   
             + ' '''','''','''','''','''','     --15       
             + CHAR(13) +      
             + ' '''','''','''','''','''','         --20      
             + ' '''','''','''','''','''','
             + ' '''','''','''','''','''','         --30
             + ' '''','''','''','''','''','
             + ' '''','''','''','''','''','         --40      
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''',RECDET.Receiptkey '   --60          
             + CHAR(13) +   
             + ' FROM RECEIPT REC WITH (NOLOCK)'    
             + ' JOIN RECEIPTDETAIL RECDET WITH (NOLOCK) ON REC.Receiptkey=RECDET.Receiptkey'  
             + ' JOIN SKU s WITH (NOLOCK) ON s.storerkey = RECDET.storerkey AND s.sku=RECDET.sku'  
             + ' JOIN LOC L WITH (NOLOCK) ON L.loc = RECDET.Toloc '
             --+ ' LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Listname = ''THGCUSREQ'' '
             --+ ' And C1.Storerkey = REC.Storerkey And C1.Code = ''RECLOC'' And C1.Short = ''NORMAL'' And C1.Code2 = RECDET.ToLoc '
             + ' WHERE RECDET.receiptkey =  @c_Sparm01  AND RECDET.toid = @c_Sparm02 '   + CHAR(13)
            
             
                       
      IF @b_debug=1        
      BEGIN        
         PRINT @c_SQLJOIN + @c_GroupBy   
      END                
              
    SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
     SET @c_SQL = @c_SQL + @c_SQLJOIN  + @c_condition + @c_GroupBy

     SET @c_ExecArguments = N'   @c_Sparm01        NVARCHAR(80)'  
                          + ',   @c_Sparm02        NVARCHAR(80)'  
                           
                         
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01    
                        , @c_Sparm02        
        
    -- EXEC sp_executesql @c_SQL          
        
   IF @b_debug=1        
   BEGIN          
     PRINT @c_SQL          
   END 

     
   IF @b_debug=1        
   BEGIN        
     SELECT * FROM #Result (nolock)        
   END     
   
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  SELECT DISTINCT col60,col07--,col09     
   FROM #Result               
   WHERE Col60 = @c_Sparm01
   and col07=@c_Sparm02       
          
   OPEN CUR_RowNoLoop                  
             
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_receiptkey,@c_RDTOID--,@c_putawayzone    
               
   WHILE @@FETCH_STATUS <> -1             
   BEGIN                 
      IF @b_debug='1'              
      BEGIN              
         PRINT @c_receiptkey                 
      END  
      
      SET @c_LocAisle = ''
      SET @c_putawayzone  = ''

      IF EXISTS (SELECT 1 
                 FROM RECEIPT R WITH (NOLOCK)
                 JOIN RECEIPTDETAIL RECDET WITH (NOLOCK) ON R.Receiptkey=RECDET.Receiptkey
                 JOIN CODELKUP C WITH (NOLOCK) ON C.listname ='THGCUSREQ'
                 AND C.Storerkey = R.Storerkey And C.Code = 'RECLOC' And C.Short = 'NORMAL' And C.Code2 = RECDET.ToLoc
                 WHERE R.receiptkey = @c_receiptkey AND RECDET.toid= @c_RDTOID)
      BEGIN
        SELECT @c_putawayzone = S.putawayzone
        FROM RECEIPT REC WITH (NOLOCK)  
        JOIN RECEIPTDETAIL RECDET WITH (NOLOCK) ON REC.Receiptkey=RECDET.Receiptkey 
        JOIN SKU s WITH (NOLOCK) ON s.storerkey = RECDET.storerkey AND s.sku=RECDET.sku 
        JOIN LOC L WITH (NOLOCK) ON L.loc = RECDET.Toloc 
        WHERE RECDET.receiptkey =  @c_receiptkey  AND RECDET.toid = @c_RDTOID
         
        SELECT TOP 1 @c_LocAisle = L.locaisle
        FROM LOC L WITH (NOLOCK)
        WHERE L.putawayzone =   @c_putawayzone

      END
      ELSE IF EXISTS (SELECT 1 
                 FROM RECEIPT R WITH (NOLOCK)
                 JOIN RECEIPTDETAIL RECDET WITH (NOLOCK) ON R.Receiptkey=RECDET.Receiptkey
                 JOIN CODELKUP C WITH (NOLOCK) ON C.listname ='THGCUSREQ'
                 AND C.Storerkey = R.Storerkey And C.Code = 'RECLOC' And C.Short = 'NEWSKU' And C.Code2 = RECDET.ToLoc
                 WHERE R.receiptkey = @c_receiptkey AND RECDET.toid= @c_RDTOID)
      BEGIN
        SELECT @c_putawayzone = l.putawayzone
        FROM RECEIPT REC WITH (NOLOCK)  
        JOIN RECEIPTDETAIL RECDET WITH (NOLOCK) ON REC.Receiptkey=RECDET.Receiptkey 
        JOIN SKU s WITH (NOLOCK) ON s.storerkey = RECDET.storerkey AND s.sku=RECDET.sku 
        JOIN LOC L WITH (NOLOCK) ON L.loc = RECDET.Toloc 
         WHERE RECDET.receiptkey =  @c_receiptkey  AND RECDET.toid = @c_RDTOID
      END
      ELSE
      BEGIN
        SELECT @c_putawayzone = l.putawayzone
        FROM RECEIPT REC WITH (NOLOCK)  
        JOIN RECEIPTDETAIL RECDET WITH (NOLOCK) ON REC.Receiptkey=RECDET.Receiptkey 
        JOIN SKU s WITH (NOLOCK) ON s.storerkey = RECDET.storerkey AND s.sku=RECDET.sku 
        JOIN LOC L WITH (NOLOCK) ON L.loc = RECDET.Toloc 
         WHERE RECDET.receiptkey =  @c_receiptkey  AND RECDET.toid = @c_RDTOID

        SELECT TOP 1 @c_LocAisle = L.locaisle
        FROM LOC L WITH (NOLOCK)
        WHERE L.putawayzone =   @c_putawayzone 

      END                          
      
      --IF @c_putawayzone <> 'PF-ERROR'
      --BEGIN
      --  SELECT TOP 1 @c_LocAisle = L.locaisle
      --  FROM LOC L WITH (NOLOCK)
      --  WHERE L.putawayzone =   @c_putawayzone
      --  END

       UPDATE #Result                  
       SET   Col08 = @c_LocAisle 
            ,col09 = @c_putawayzone
       WHERE Col60 = @c_receiptkey
        AND   col07=@c_RDTOID       
  
   FETCH NEXT FROM CUR_RowNoLoop INTO  @c_receiptkey,@c_RDTOID--,@c_putawayzone         
        
      END -- While                   
      CLOSE CUR_RowNoLoop                  
      DEALLOCATE CUR_RowNoLoop   
      
   SELECT * FROM #Result (nolock)        
            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
     
      EXEC isp_InsertTraceInfo   
         @c_TraceCode = 'BARTENDER',  
         @c_TraceName = 'isp_Bartender_PALLETLBL_SG_THGBT',  
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
   
  
                                  
   END -- procedure  
        

GO