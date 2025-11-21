SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                       
/* Copyright: IDS                                                             */                       
/* Purpose: BarTender UCCLBLSEP Label                                         */                       
/*                                                                            */                       
/* Modifications log:                                                         */                       
/*                                                                            */                       
/* Date       Rev  Author     Purposes                                        */                       
/* 2020-04-29 1.0  CSCHONG    Created(WMS-12966)                              */          
/******************************************************************************/                      
                        
CREATE PROC [dbo].[isp_BT_Bartender_UCCLBLSEP_Label]                             
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
                                    
   DECLARE         
      @c_receiptkey      NVARCHAR(10),        
      @c_lottable02      NVARCHAR(80),                      
      @c_lottable01      NVARCHAR(80),        
      @C_sku             NVARCHAR(80),        
      @C_Size            NVARCHAR(80),        
      @C_BUSR6           NVARCHAR(80),        
      @c_Rreceiptkey     NVARCHAR(10),        
      @c_Rlottable02     NVARCHAR(80),                      
      @c_Rlottable01     NVARCHAR(80),        
      @C_Rsku            NVARCHAR(80),        
      @C_RSize           NVARCHAR(80),        
      @C_RBUSR6          NVARCHAR(80),        
      @c_GetCol01        NVARCHAR(80),        
      @c_GetCol02        NVARCHAR(80),        
      @c_GetCol03        NVARCHAR(80),        
      @c_GetCol04        NVARCHAR(80),        
      @c_GetCol05        NVARCHAR(80),        
      @c_GetCol06        NVARCHAR(80),        
      @c_GetCol07        NVARCHAR(80),        
      @c_GetCol08        NVARCHAR(80),        
      @n_intFlag         INT,             
      @n_CntRec          INT          
        
  DECLARE @d_Trace_StartTime   DATETIME,         
           @d_Trace_EndTime    DATETIME,        
           @c_Trace_ModuleName NVARCHAR(20),         
           @d_Trace_Step1      DATETIME,         
           @c_Trace_Step1      NVARCHAR(20),        
           @c_UserName         NVARCHAR(20)          
                   
         
   SET @d_Trace_StartTime = GETDATE()        
   SET @c_Trace_ModuleName = ''        
   SET @n_intFlag = 1        
        
   IF ISNULL(@c_SParm4,'') <> ''        
   BEGIN        
     SET @n_CntRec = CONVERT(INT,@c_SParm4)        
   END                     
                    
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
        
 IF ISNULL(@c_Sparm4,'') <> ''        
 BEGIN          
        
   INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                 
            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22               
            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                
            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                 
            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54               
            ,Col55,Col56,Col57,Col58,Col59,Col60)           
   SELECT DISTINCT RECD.Storerkey, RECD.SKU,substring(s.descr,1,80),s.altsku,RECD.lottable02,        
                   RECD.lottable03,convert(nvarchar(10),RECD.lottable04, 126),CASE WHEN s.susr1 = 'ANTIVOL' THEN 'Y' ELSE 'N' END,s.busr4,convert(nvarchar(20), getdate(), 120) ,         
                   RECD.EDITWHO,CASE WHEN SUM(RECD.QtyReceived) > 0 THEN SUM(RECD.QtyReceived) ELSE SUM(RECD.BeforeReceivedQty) END,        
                   RECD.userdefine01,'','','','','','','',  --20        
                   '','','','','','','','','','',         
                   '','','','','','','','','','',         
                   '','','','','','','','','','',         
                   '','','','','','','','','',''            
  FROM RECEIPTDETAIL RECD WITH (NOLOCK)        
  JOIN SKU s WITH (NOLOCK) ON s.sku=RECD.sku AND S.storerkey = RECD.StorerKey          
  WHERE RECD.StorerKey = @c_Sparm1         
  AND RECD.receiptKey = @c_Sparm2          
  AND RECD.UserDefine01 = @c_Sparm3        
  AND RECD.sku = @c_Sparm4             
  GROUP BY RECD.Storerkey, RECD.SKU,substring(s.descr,1,80),s.altsku,RECD.lottable02,        
           RECD.lottable03,RECD.lottable04,s.susr1,s.busr4,RECD.EDITWHO,        
           RECD.userdefine01        
        
        
   IF @b_debug=1              
   BEGIN              
    SELECT * FROM #Result (nolock)              
   END         
           
  END        
  ELSE        
  BEGIN         
     INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                 
             ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22               
             ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                
             ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                 
             ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54               
             ,Col55,Col56,Col57,Col58,Col59,Col60)           
     SELECT DISTINCT U.Storerkey,U.sku,substring(s.descr,1,80),s.altsku,LOTT.Lottable02,        
                     LOTT.Lottable03,convert(nvarchar(10),LOTT.Lottable04,126),CASE WHEN s.susr1 = 'ANTIVOL' THEN 'Y' ELSE 'N' END,s.busr4,convert(nvarchar(20),getdate(), 120),         
                     U.EditWho,SUM(U.Qty),U.UCCno,'','','','','','','',  --20        
                     '','','','','','','','','','',         
                     '','','','','','','','','','',         
                     '','','','','','','','','','',         
                     '','','','','','','','','',''           
     FROM UCC U WITH (NOLOCK)        
     JOIN SKU s WITH (NOLOCK) ON s.sku=U.sku AND S.storerkey = U.StorerKey          
     JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = U.lot        
     WHERE U.Storerkey = @c_Sparm1        
           AND U.UCCno = @c_Sparm2        
           AND U.sku = @c_Sparm3        
     GROUP BY U.Storerkey,U.sku,substring(s.descr,1,80),s.altsku,LOTT.Lottable02,        
              LOTT.Lottable03,LOTT.Lottable04,s.susr1,s.busr4,U.EditWho,         
              U.UCCno        
        
         IF @b_debug=1              
         BEGIN              
          SELECT * FROM #Result (nolock)              
         END         
 END        
        
   SELECT * FROM #Result (nolock)        
        
   EXIT_SP:          
        
   SET @d_Trace_EndTime = GETDATE()        
   SET @c_UserName = SUSER_SNAME()        
           
   EXEC isp_InsertTraceInfo         
      @c_TraceCode = 'BARTENDER',        
      @c_TraceName = 'isp_BT_Bartender_UCCLBLSEP_Label',        
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
         
                                  
END 

GO