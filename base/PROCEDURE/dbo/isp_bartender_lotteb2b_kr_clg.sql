SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                       
/* Copyright: IDS                                                             */                       
/* Purpose: isp_BT_SHIPLBL_KR_LOTTE                                           */                       
/*                                                                            */                       
/* Modifications log:                                                         */                       
/*                                                                            */                       
/* Date       Rev  Author     Purposes                                        */                       
/* 2022-03-21 1.0  CSCHONG    Devops Scripts Combine & Created (WMS-19092)    */ 
/******************************************************************************/                      
                        
CREATE PROC [dbo].[isp_Bartender_LOTTEB2B_KR_CLG]                            
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
       
            
          
  DECLARE @d_Trace_StartTime   DATETIME,         
           @d_Trace_EndTime    DATETIME,        
           @c_Trace_ModuleName NVARCHAR(20),         
           @d_Trace_Step1      DATETIME,         
           @c_Trace_Step1      NVARCHAR(20),        
           @c_UserName         NVARCHAR(20),      
           @c_SQL             NVARCHAR(4000),            
           @c_SQLJOIN         NVARCHAR(4000)               
                 
 DECLARE @c_ExecStatements         NVARCHAR(MAX)        
         , @c_ExecArguments        NVARCHAR(MAX)        
         , @c_ExecStatements2      NVARCHAR(MAX)        
         , @c_ExecStatementsAll    NVARCHAR(MAX)          
         , @n_continue             INT     
           
         ,@c_Col13            NVARCHAR(80)    
         ,@c_Col14            NVARCHAR(80)  
         ,@c_Col15            NVARCHAR(80)  
         ,@c_Col16            NVARCHAR(80)  
         ,@c_Col17            NVARCHAR(80)  
         ,@c_Col18            NVARCHAR(80)  
         ,@c_Col19            NVARCHAR(80)  
         ,@c_Col20            NVARCHAR(80)  
         ,@c_Col21            NVARCHAR(80)  
         ,@n_ID               INT  
         ,@c_Pickslipno       NVARCHAR(80)  
         ,@c_dropid           NVARCHAR(80)  
         ,@c_LabelLine        NVARCHAR(80)  
         ,@c_Sku              NVARCHAR(80)  
         ,@c_descr            NVARCHAR(80)  
         ,@c_qty              NVARCHAR(80)  
         ,@c_Col22            NVARCHAR(80)    
         ,@c_Col23            NVARCHAR(80)  
         ,@c_Col24            NVARCHAR(80)  
         ,@c_Col25            NVARCHAR(80)  
         ,@c_Col26            NVARCHAR(80)  
         ,@c_Col27            NVARCHAR(80)  
         ,@c_Col28            NVARCHAR(80)  
         ,@c_Col29            NVARCHAR(80)  
         ,@c_Col30            NVARCHAR(80)  
         ,@n_MaxCtn           INT  = 0
         ,@c_GetPickslipno    NVARCHAR(80) = ''

                      
        
   SET @d_Trace_StartTime = GETDATE()        
   SET @c_Trace_ModuleName = ''        
              
    -- SET RowNo = 0                   
    SET @c_SQL = ''       
        
                    
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
       
     CREATE TABLE [#PADItem] (                 
      [ID]           [INT] IDENTITY(1,1) NOT NULL,    
      [Pickslipno]   NVARCHAR(20) NULL,   
      [dropid]       NVARCHAR(50) NULL,     
      [LabelLine]    NVARCHAR(50) NULL,   
      [SKU]          NVARCHAR(30) NULL,      
      [ItemDescr]    NVARCHAR(80) NULL,  
      [QTY]          NVARCHAR(20) NULL)    
                  
         IF @b_debug=1              
         BEGIN              
            PRINT 'start'                
         END              
SET @c_SQLJOIN = +' SELECT DISTINCT LEFT(OH.C_Address3 ,13),ISNULL(substring(c.Long,1,80),''''),ISNULL(substring(c.Notes,1,80),''''),ISNULL(substring(csc.comment,1,80),'''')'  --4
     + ',ISNULL(substring(csc.sortingcode2,1,80),''''),ISNULL(csc.state,''''),ISNULL(csc.city,'''') , ISNULL(csc.province,''''),ISNULL(c.UDF01,''''),ISNULL(CT.trackingno,'''')' + CHAR(13) --10     
     +' ,GETDATE() ' + CHAR(13) --11    
     +' ,ISNULL(substring(csc.sortingcode3,1,80),''''),'''', '''' ' + CHAR(13) --15    
     +' ,'''','''','''','''','''','''' ' + CHAR(13) --20 
     + ','''','''','''','''','''','''','''','''','''','''' ' + CHAR(13) --30    
     + ',PD.Cartonno,'''',OH.ExternOrderkey,OH.Orderkey,ISNULL(OH.Userdefine03,''''),'''','''','''','''','''' ' + CHAR(13) --40 
     + ','''','''','''','''','''','''','''','''','''','''' ' + CHAR(13) --50      
     +' ,'''','''','''','''','''','''','''','''',pd.DropID,''KR'' ' + CHAR(13) --60       
     + ' FROM PackDetail AS pd WITH(NOLOCK) ' + CHAR(13) --60  
     + ' JOIN PackHeader AS ph WITH(NOLOCK) ON ph.PickSlipNo = pd.PickSlipNo ' + CHAR(13) --60  
     + ' JOIN ORDERS OH (NOLOCK) ON ph.OrderKey = OH.OrderKey ' + CHAR(13) --60  
     + ' JOIN CartonTrack AS ct WITH(NOLOCK) ON pd.LabelNo = ct.trackingno AND ct.CarrierName = ''LOTTE10'' ' + CHAR(13) --60  
     + ' LEFT OUTER JOIN CODELKUP AS c WITH(NOLOCK) ON c.LISTNAME = ''LOTTELBL'' AND c.Code = OH.ConsigneeKey ' + CHAR(13) --60  
     + ' LEFT OUTER JOIN couriersortingcode AS csc WITH(NOLOCK) ON c.description = csc.sortingcode1 and csc.shipperkey = ''LOTTE10'' ' + CHAR(13) --60  
     + ' WHERE pd.DropID = @c_Sparm01 ' + CHAR(13) --60  
    
                             
   IF @b_debug=1              
   BEGIN              
      PRINT @c_SQLJOIN                
   END                      
                    
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +                 
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +                 
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +                 
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +                 
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +                 
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '                
          
      
       SET @c_ExecStatements = @c_SQL + CHAR(13) + @c_SQLJOIN       
             
       IF @b_debug=1              
       BEGIN              
         SELECT @c_ExecStatements                
       END        
             
       SET @c_ExecArguments = N'@c_Sparm01    NVARCHAR(60)'        
                             +',@c_Sparm02    NVARCHAR(60)'        
                                           
        
        EXEC sp_ExecuteSql @c_ExecStatements         
                         , @c_ExecArguments        
                         , @c_Sparm01        
                         , @c_Sparm02        
        
     IF @@ERROR <> 0             
     BEGIN        
       SET @n_continue = 3        
       ROLLBACK TRAN        
       GOTO EXIT_SP        
     END             
      
          
              
   --EXEC sp_executesql @c_SQL                
              
   IF @b_debug=1              
   BEGIN                
       PRINT @c_SQL                
   END        
     
   INSERT INTO #PADItem (Pickslipno,dropid,LabelLine,Sku,ItemDescr,QTY)     
   SELECT DISTINCT TOP 6 PAD.Pickslipno, PAD.DropID, PAD.LabelLine, PAD.SKU, LTRIM(RTRIM(S.descr)), CAST(PAD.QTY AS NVARCHAR)  
   FROM PACKDETAIL PAD (NOLOCK)                  
   JOIN SKU S WITH (NOLOCK) ON (S.SKU = PAD.SKU AND S.STORERKEY = PAD.STORERKEY)  
   WHERE PAD.dropid = @c_sparm01 
   ORDER BY PAD.Pickslipno, PAD.DropID, PAD.LabelLine  
     
   SET @c_Col13 = ''   
   SET @c_Col14 = ''   
   SET @c_Col15 = ''   
   SET @c_Col16 = ''   
   SET @c_Col17 = ''   
   SET @c_Col18 = ''   
   SET @c_Col19 = ''   
   SET @c_Col20 = ''   
   SET @c_Col21 = ''   
  
   SET @c_Col22 = ''   
   SET @c_Col23 = ''   
   SET @c_Col24 = ''   
   SET @c_Col25 = ''   
   SET @c_Col26 = ''   
   SET @c_Col27 = ''   
   SET @c_Col28 = '' 
   SET @c_Col29 = '' 
   SET @c_Col30 = '' 

   SET @c_GetPickslipno = ''
   SET @n_MaxCtn = 0

   SELECT @c_GetPickslipno = Pickslipno
   FROM #PADItem 
   WHERE dropid = @c_Sparm01

   SELECT @n_MaxCtn = MAX(cartonno)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @c_GetPickslipno
 
     
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT DISTINCT ID, Pickslipno,dropid,LabelLine,Sku,ItemDescr,QTY  
   FROM #PADItem  
   WHERE Dropid = @c_sparm01 
   ORDER BY ID  
     
   OPEN CUR_RESULT  
     
   FETCH NEXT FROM CUR_RESULT INTO @n_ID, @c_Pickslipno, @c_dropid, @c_LabelLine, @c_Sku, @c_descr, @c_QTY  
     
   WHILE @@FETCH_STATUS <>-1  
   BEGIN  
 

   IF @n_ID = 1   
   BEGIN  
         SET @c_Col13 = @c_Sku  
         SET @c_Col14 = @c_descr  
         SET @c_Col15 = @c_QTY  
   END  
   ELSE IF @n_ID = 2   
   BEGIN  
         SET @c_Col16 = @c_Sku  
         SET @c_Col17 = @c_descr  
         SET @c_Col18 = @c_QTY  
   END  
   ELSE IF @n_ID = 3   
   BEGIN  
         SET @c_Col19 = @c_Sku  
         SET @c_Col20 = @c_descr  
         SET @c_Col21 = @c_QTY  
   END   
   ELSE IF @n_ID = 4  
   BEGIN  
         SET @c_Col22 = @c_Sku  
         SET @c_Col23 = @c_descr  
         SET @c_Col24 = @c_QTY  
   END  
   ELSE IF @n_ID = 5   
   BEGIN  
         SET @c_Col25 = @c_Sku  
         SET @c_Col26 = @c_descr  
         SET @c_Col27 = @c_QTY  
   END  
   ELSE IF @n_ID = 6   
   BEGIN  
         SET @c_Col28 = @c_Sku  
         SET @c_Col29 = @c_descr  
         SET @c_Col30 = @c_QTY  
   END  
  
   FETCH NEXT FROM CUR_RESULT INTO @n_ID, @c_Pickslipno, @c_dropid, @c_LabelLine, @c_Sku, @c_descr, @c_QTY  
   END  
     
   CLOSE CUR_RESULT    
   DEALLOCATE CUR_RESULT    
     
   UPDATE #Result    
   SET Col13 = @c_Col13,    
       Col14 = @c_Col14,    
       Col15 = @c_Col15,    
       Col16 = @c_Col16,    
       Col17 = @c_Col17,  
       Col18 = @c_Col18,  
       Col19 = @c_Col19,  
       Col20 = @c_Col20,  
       Col21 = @c_Col21,  
       Col22 = @c_Col22,  
       Col23 = @c_Col23,  
       Col24 = @c_Col24,  
       Col25 = @c_Col25,   
       Col26 = @c_Col26,  
       Col27 = @c_Col27,  
       Col28 = @c_Col28,  
       Col29 = @c_Col29,  
       Col30 = @c_Col30      
   WHERE Col59 =@c_Sparm01    
 
     
   IF @b_debug=1              
   BEGIN              
      SELECT * FROM #Result (nolock)              
   END              
            
   SELECT * FROM #Result (nolock)              
                  
   EXIT_SP:          
        
      SET @d_Trace_EndTime = GETDATE()        
      SET @c_UserName = SUSER_SNAME()        
           
      EXEC isp_InsertTraceInfo         
         @c_TraceCode = 'BARTENDER',        
         @c_TraceName = 'isp_Bartender_LOTTEB2B_KR_CLG',        
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