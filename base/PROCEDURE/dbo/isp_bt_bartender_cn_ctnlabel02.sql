SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_CN_CTNLABEL02                                    */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2019-07-26 1.0  CSCHONG    Created (WMS-9965&WMS-9990)                     */ 
/* 2019-09-05 1.1  CSCHONG    WMS-10384 revised print logic (CS01)            */ 
/* 2021-10-01 1.2  MINGLE     WMS-18051 add lottable02 (ML01)                 */ 
/* 2021-10-14 1.2  Mingle     DevOps Combine Script                           */
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_CN_CTNLABEL02]                      
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
                                  
          
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20)  
         
 DECLARE @c_Altsku             NVARCHAR(20)
        ,@c_Lott04             NVARCHAR(10)
        ,@n_casecnt            FLOAT
        ,@n_looseqty           INT
        ,@c_Qty                NVARCHAR(10)  
        ,@c_sdescr             NVARCHAR(80) 
        ,@c_Lott02             NVARCHAR(10)     --ML01                    
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
              
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
        

    SET @c_Qty = ''

    SELECT @c_Altsku = S.AltSku
          ,@n_casecnt = P.casecnt
          ,@n_looseqty = (sum(PD.QTY)%cast(P.casecnt as int))
          ,@c_Lott04  = CONVERT(NVARCHAR(10),LOTT.Lottable04,101)
          ,@c_sdescr = ISNULL(S.descr,'')
          ,@c_Lott02 = LOTT.Lottable02    --ML01
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.Sku = PD.Sku
   JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey
   JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PD.lot and LOTT.SKU = PD.SKU
                                        AND LOTT.Storerkey = PD.Storerkey 
   WHERE PD.OrderKey = @c_Sparm04
   AND PD.Sku = @c_Sparm06
   AND CONVERT(NVARCHAR(10),LOTT.Lottable04,101) = @c_Sparm10
   GROUP BY S.AltSku,P.casecnt, CONVERT(NVARCHAR(10),LOTT.Lottable04,101),ISNULL(S.descr,''),LOTT.Lottable02    --ML01
      
   IF @c_Sparm03 = 'Full'
   BEGIN
    SET @c_Qty = CAST(@n_casecnt as nvarchar(10))
   END
   ELSE
   BEGIN
    SET @c_Qty = CAST(@n_looseqty as nvarchar(10))
   END
          
    INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                            ,Col55,Col56,Col57,Col58,Col59,Col60)             
     VALUES(@c_Sparm01,@c_Sparm02,@c_Sparm03,@c_Altsku,@c_sdescr,@c_Qty,           
            @c_Lott04,@c_Sparm05,@c_Lott02,'','','','','','','','','','','',            --ML01  
            '','','','','','','','','','','','','','','','','','','','','','','','','','','','','',''          
            ,'','','','','','','','','','O')          
            
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_CN_CTNLABEL02',  
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
     QUIT: 
                                
                                 
END -- procedure   



GO