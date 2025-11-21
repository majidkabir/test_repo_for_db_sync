SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: LFL                                                             */                 
/* Purpose: isp_Bartender_PALLETLBL_RG_LEGO                                   */                 
/*          Copy from isp_Bartender_PALLETLBL_SG_IDSMED and modify            */   
/*                                                                            */              
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-12-23 1.0  WLChooi    Created (WMS-15952)                             */    
/* 2021-03-03 1.1  WLChooi    WMS-15952 No filter by ReceiptLineNumber (WL01) */      
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_PALLETLBL_RG_LEGO]                      
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
                              
   DECLARE @c_ReceiptKey        NVARCHAR(10),                    
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
           @c_OrderBy           NVARCHAR(4000),
           @c_ExecStatements    NVARCHAR(4000),   
           @c_ExecArguments     NVARCHAR(4000),
           @c_RDTOID            NVARCHAR(20),
           @c_Putawayzone       NVARCHAR(30),
           @c_LocAisle          NVARCHAR(30),
           @c_reclinenumber     NVARCHAR(20)
               
   
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

   SET @c_condition = ''
   SET @c_GroupBy = ''
   SET @c_OrderBy = ''
   SET @c_reclinenumber = ''
   
   --WL01 Comment
   --SELECT TOP 1 @c_reclinenumber = RD.receiptlinenumber
   --FROM RECEIPTDETAIL RD WITH (NOLOCK)
   --WHERE RD.receiptkey =  @c_Sparm01  AND RD.toid = @c_Sparm02
   --AND RD.SKU = CASE WHEN ISNULL(@c_Sparm03,'') = '' THEN RD.SKU ELSE @c_Sparm03 END
   --AND RD.finalizeflag = 'Y'
   --ORDER BY RD.editdate desc
   
   SET @c_GroupBy =  ''
   
   SET @c_OrderBy = ' ORDER BY RD.EditDate desc'
            
   SET @c_SQLJOIN = + ' SELECT DISTINCT RD.SKU, ISNULL(S.Descr,''''), ' + CHAR(13)   --2
                    + ' CASE WHEN ISNULL(P.Casecnt,0) > 0 THEN FLOOR(SUM(RD.QtyReceived) / P.Casecnt) ELSE 0 END, ' + CHAR(13)   --3   --WL01   
                    + ' CASE WHEN ISNULL(P.Casecnt,0) > 0 THEN SUM(RD.QtyReceived) - (FLOOR(SUM(RD.QtyReceived) / P.Casecnt) * P.Casecnt) ELSE 0 END, ' + CHAR(13)   --4   --WL01
                    + ' S.PutawayZone, ' + CHAR(13)   --5
                    + ' RD.Lottable03, RD.ToID, ISNULL(RD.Lottable01,''''), RD.Lottable05, ISNULL(RD.Lottable07,''''), ' + CHAR(13)   --10   
                    + ' ISNULL(RD.Lottable08,''''), ISNULL(RD.Lottable09,''''), R.ExternReceiptKey,' + CHAR(13)   --13         
                    + ' RD.ExternPOKey, RD.POKey, S.SKUGroup, S.ItemClass, SUM(RD.QtyReceived),'''','''', ' + CHAR(13)   --20   --WL01
                    + ' '''','''','''','''','''',' + CHAR(13)
                    + ' '''','''','''','''','''',' + CHAR(13)   --30
                    + ' '''','''','''','''','''',' + CHAR(13)
                    + ' '''','''','''','''','''',' + CHAR(13)   --40      
                    + ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13)   --50       
                    + ' '''','''','''','''','''','''','''','''','''',RD.Receiptkey ' + CHAR(13)   --60          
                    + ' FROM RECEIPTDETAIL RD (NOLOCK) ' + CHAR(13)
                    + ' JOIN RECEIPT R (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey ' + CHAR(13)
                    + ' JOIN SKU S (NOLOCK) ON S.SKU = RD.SKU AND S.StorerKey = RD.StorerKey ' + CHAR(13)
                    + ' JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey ' + CHAR(13)
                    + ' WHERE RD.ReceiptKey =  @c_Sparm01 AND RD.ToID = @c_Sparm02 '   + CHAR(13) 
                    --WL01 S
                    + ' GROUP BY RD.SKU, ISNULL(S.Descr,''''), ' + CHAR(13)   --2
                    --+ '          CASE WHEN ISNULL(P.Casecnt,0) > 0 THEN FLOOR(RD.QtyReceived / P.Casecnt) ELSE 0 END, ' + CHAR(13)   --3   --WL01
                    --+ '          CASE WHEN ISNULL(P.Casecnt,0) > 0 THEN RD.QtyReceived - (FLOOR(RD.QtyReceived / P.Casecnt) * P.Casecnt) ELSE 0 END, ' + CHAR(13)   --4   --WL01
                    + '          S.PutawayZone, P.Casecnt,' + CHAR(13)   --5   --WL01
                    + '          RD.Lottable03, RD.ToID, ISNULL(RD.Lottable01,''''), RD.Lottable05, ISNULL(RD.Lottable07,''''), ' + CHAR(13)   --10   
                    + '          ISNULL(RD.Lottable08,''''), ISNULL(RD.Lottable09,''''), R.ExternReceiptKey,' + CHAR(13)   --13         
                    + '          RD.ExternPOKey, RD.POKey, S.SKUGroup, S.ItemClass,RD.Receiptkey '   --20
                    --WL01 E
                    --+ ' AND RD.ReceiptLineNumber = @c_reclinenumber '   --WL01
                     
   IF @b_debug=1        
   BEGIN  
      SELECT @c_SQLJOIN + @c_GroupBy         
      PRINT @c_SQLJOIN + @c_GroupBy   
   END                
              
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             +',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
   SET @c_SQL = @c_SQL + @c_SQLJOIN  + @c_condition + @c_GroupBy 
   
   SET @c_ExecArguments = N'  @c_Sparm01        NVARCHAR(80)'  
                         + ', @c_Sparm02        NVARCHAR(80)'  
                         + ', @c_reclinenumber  NVARCHAR(10)'
                         + ', @c_Sparm03        NVARCHAR(80)' 
                               
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01    
                        , @c_Sparm02  
                        , @c_reclinenumber  
                        , @c_Sparm03
        
   -- EXEC sp_executesql @c_SQL          
        
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL                 
      SELECT * FROM #Result (nolock)        
   END     
       
   SELECT * FROM #Result (nolock)        
            
EXIT_SP:    
   
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   --EXEC isp_InsertTraceInfo   
   --      @c_TraceCode = 'BARTENDER',  
   --      @c_TraceName = 'isp_Bartender_PALLETLBL_RG_LEGO',  
   --      @c_starttime = @d_Trace_StartTime,  
   --      @c_endtime = @d_Trace_EndTime,  
   --      @c_step1 = @c_UserName,  
   --      @c_step2 = '',  
   --      @c_step3 = '',  
   --      @c_step4 = '',  
   --      @c_step5 = '',  
   --      @c_col1 = @c_Sparm01,   
   --      @c_col2 = @c_Sparm02,  
   --      @c_col3 = @c_Sparm03,  
   --      @c_col4 = @c_Sparm04,  
   --      @c_col5 = @c_Sparm05,  
   --      @b_Success = 1,  
   --      @n_Err = 0,  
   --      @c_ErrMsg = ''              
                              
END -- procedure      

GO