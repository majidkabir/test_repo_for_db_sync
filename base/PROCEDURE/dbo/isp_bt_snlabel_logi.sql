SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_SNLABEL_LOGI                                               */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/*25-JAN-2021 1.0  CSCHONG   Created (WMS-16137)                              */  
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_SNLABEL_LOGI]                        
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
      @c_storerkey       NVARCHAR(20),                      
      @c_sn              NVARCHAR(20),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_col58           NVARCHAR(10),
      @c_labelline       NVARCHAR(10),
      @n_CartonNo        INT        
      
   DECLARE @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20), 
           @c_GetSN            NVARCHAR(80),      
           @c_SN01             NVARCHAR(80),           
           @c_SN02             NVARCHAR(80),    
           @c_SN03             NVARCHAR(80),           
           @c_SN04             NVARCHAR(80),   
           @c_SN05             NVARCHAR(80),           
           @c_SN06             NVARCHAR(80),  
           @c_SN07             NVARCHAR(80),  
           @c_SN08             NVARCHAR(80),         
           @n_TTLpage          INT,          
           @n_CurrentPage      INT,  
           @n_MaxLine          INT  ,  
           @c_labelno          NVARCHAR(20) ,  
           @c_orderkey         NVARCHAR(20) ,  
           @n_skuqty           INT ,  
           @n_qtybypage        INT ,  
           @c_cartonno         NVARCHAR(5),  
           @n_loopno           INT,  
           @c_LastRec          NVARCHAR(1),  
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000),   
           
           @c_MaxLBLLine       INT,
           @c_SumQTY           INT,
           @n_MaxCarton        INT,
           @c_Made             NVARCHAR(80),
           @n_SumPack          INT,
           @n_SumPick          INT,
           @n_MaxCtnNo         INT, 
           @c_altsku           NVARCHAR(20),  
           @c_SerialType       NVARCHAR(1),     
           @c_SerialNo         NVARCHAR(20) 
    
    SET @d_Trace_StartTime = GETDATE()    
    SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''       
    SET @n_CurrentPage = 1  
    SET @n_TTLpage =1       
    SET @n_MaxLine = 8              
    SET @n_CntRec = 1    
    SET @n_intFlag = 1   
    SET @n_loopno = 1        
    SET @c_LastRec = 'Y'  
                
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
       
     CREATE TABLE [#tempSerialNo] (                       
      [Rowid]    [INT] NOT NULL,                                      
      [SerialNo] [NVARCHAR] (80) NULL,                        
      [ParentSerialNo] [NVARCHAR] (80) NULL                    
     )  
  
   CREATE TABLE [#tempC_SerialNo] (                                            
      [SerialNoType] [NVARCHAR] (1) NULL,  
      [SerialNo] [NVARCHAR] (80) NULL,                        
      [ParentSerialNo] [NVARCHAR] (80) NULL                    
     ) 

   SELECT @c_SerialType = ISNULL(RIGHT(RTRIM(@c_Sparm02),1),'')  
  
   IF @c_SerialType ='9'  
   BEGIN  
     INSERT INTO #tempSerialNo (Rowid,  
                               SerialNo,  
                               ParentSerialNo)  
      SELECT ROW_NUMBER() OVER (ORDER BY SerialNo),SerialNo,'' FROM dbo.MasterSerialNo (NOLOCK) WHERE StorerKey=@c_Sparm01 AND SerialNo=@c_Sparm02  
   END  
   ELSE  
   BEGIN  
     INSERT INTO #tempC_SerialNo (SerialNoType,  
                                  SerialNo,  
                                  ParentSerialNo)  
     SELECT ISNULL(RIGHT(RTRIM(SerialNo),1),''),SerialNo,ParentSerialNo FROM dbo.MasterSerialNo (NOLOCK) WHERE StorerKey=@c_Sparm01 AND ParentSerialNo=@c_Sparm02   
     
     IF EXISTS(SELECT 1 FROM #tempC_SerialNo WHERE SerialNoType='C')  
     BEGIN   
       INSERT INTO #tempSerialNo (Rowid,  
                                  SerialNo,  
                                  ParentSerialNo)  
       SELECT ROW_NUMBER() OVER (ORDER BY MS.SerialNo),MS.SerialNo,TCS.ParentSerialNo FROM dbo.MasterSerialNo MS (NOLOCK)   
       INNER JOIN #tempC_SerialNo TCS (NOLOCK) ON MS.ParentSerialNo = TCS.SerialNo AND MS.StorerKey=@c_Sparm01  
     END   
     ELSE  
     BEGIN  
       INSERT INTO #tempSerialNo (Rowid,  
                                  SerialNo,  
                                  ParentSerialNo)  
       SELECT ROW_NUMBER() OVER (ORDER BY TCS.SerialNo),TCS.SerialNo,TCS.ParentSerialNo FROM #tempC_SerialNo TCS (NOLOCK)   
     END  
  END 
      
         
       SET @c_SQLJOIN = +' SELECT '''', '''', '''','''','''','''','''','''','''','''','  + CHAR(13) --10      
                        +' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '+ CHAR(13)  --20
                        +' '''','''','''','''','''','''','''' ,'''','''','''', ' + CHAR(13) --30 
                        +' '''','''','''','''', '''','''','''','''','''','''', ' + CHAR(13) --40     
                        +' '''','''','''','''','''','''','''', '''','''','''', ' + CHAR(13) --50 
                        +' '''','''','''','''','''','''','''',@c_Sparm01, ' + CHAR(13) --58
                        +' @c_Sparm02, ''1'' ' + CHAR(13) --60               
                       
  
       
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
      
SET @c_SQL = @c_SQL + @c_SQLJOIN      
  
  
 SET @c_ExecArguments = N'     @c_Sparm01          NVARCHAR(80)'
                      +  ',    @c_Sparm02          NVARCHAR(80)'        
                           
                           
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01     
                        , @c_Sparm02 
     
          
    --EXEC sp_executesql @c_SQL            
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END    
     
           
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)          
   END      

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT col58,col59     
   FROM #Result 
   ORDER BY col59                     
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_storerkey,@c_sn   
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_labelno                   
      END   

      
      
      SET @c_SN01 = ''  
      SET @c_SN02 = ''  
      SET @c_SN03 = ''  
      SET @c_SN04 = ''  
      SET @c_SN05 = ''  
      SET @c_SN06 = ''  
      SET @c_SN07 = '' 
      SET @c_SN08 = ''  
      SET @n_qtybypage = 0
  
  --SELECT * FROM #TEMPSKU  
           
     SELECT @n_CntRec = COUNT (1)
     FROM #tempSerialNo   
     
     SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END   

     WHILE @n_intFlag <= @n_CntRec             
     BEGIN    

       IF @n_intFlag > @n_MaxLine AND (@n_intFlag%@n_MaxLine) = 1 --AND @c_LastRec = 'N'  
       BEGIN  
       
          SET @n_CurrentPage = @n_CurrentPage + 1  
          
          IF (@n_CurrentPage>@n_TTLpage)   
          BEGIN  
             BREAK;  
          END     
          
          INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                              ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                              ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                              ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                              ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                              ,Col55,Col56,Col57,Col58,Col59,Col60)   
          SELECT TOP 1 '','','','','','','','','','',                   
                       '','','','','','','','','','',                
                       '','','','','','','',
                       '','','',                
                       '','','','','','','','','','',                  
                       '','','','','','','','','','',                 
                       '','','','','','','',Col58,Col59,CAST(@n_CurrentPage as nvarchar(10))  
          FROM  #Result
          
          
          SET @c_SN01 = ''  
          SET @c_SN02 = ''  
          SET @c_SN03 = ''  
          SET @c_SN04 = ''  
          SET @c_SN05 = ''  
          SET @c_SN06 = ''  
          SET @c_SN07 = '' 
          SET @c_SN08 = '' 

          SET @n_qtybypage = 0
          
       END      
                
      SELECT @c_GetSN = SerialNo  
      FROM #tempSerialNo   
      WHERE Rowid = @n_intFlag  

      IF (@n_intFlag%@n_MaxLine) = 1 
      BEGIN            
         SET @c_SN01    = @c_GetSN  

      END

      ELSE IF (@n_intFlag%@n_MaxLine) = 2 
      BEGIN            
         SET @c_SN02 = @c_GetSN  
      
      END   

      ELSE IF (@n_intFlag%@n_MaxLine) = 3   
      BEGIN            
         SET @c_SN03 = @c_GetSN      
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 4   
      BEGIN             
         SET @c_SN04 = @c_GetSN        
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 5   
      BEGIN            
         SET @c_SN05 = @c_GetSN         
      END 

     ELSE IF (@n_intFlag%@n_MaxLine) = 6   
      BEGIN            
         SET @c_SN06 = @c_GetSN           
      END 
      ELSE IF (@n_intFlag%@n_MaxLine) = 7  
      BEGIN          
         SET @c_SN07 = @c_GetSN        
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 0   
      BEGIN          
         SET @c_SN08 = @c_GetSN  
    
      END 

      
  UPDATE #Result                    
  SET col01 = @c_SN01,
      Col02 = @c_SN02,
      Col03 = @c_SN03,
      Col04 = @c_SN04,
      Col05 = @c_SN05,
      Col06 = @c_SN06,
      col07 = @c_SN07,
      col08 = @c_SN08
    WHERE ID = @n_CurrentPage   
             
        SET @n_intFlag = @n_intFlag + 1    
  
        IF @n_intFlag > @n_CntRec  
        BEGIN  
          BREAK;  
        END        
      END  
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_cartonno          
          
   END -- While                     
   CLOSE CUR_RowNoLoop                    
   DEALLOCATE CUR_RowNoLoop
   
   SELECT * FROM #Result    

              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_SNLABEL_LOGI',    
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