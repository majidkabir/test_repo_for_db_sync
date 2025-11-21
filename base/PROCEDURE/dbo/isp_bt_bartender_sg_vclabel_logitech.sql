SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_SG_VCLABEL_LOGITECH                                */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date        Rev  Author     Purposes                                         */                   
/* 28-Apr-2022 1.0  WLChooi    Created (WMS-19550)                              */ 
/* 28-Apr-2022 1.0  WLChooi    DevOps Combine Script                            */
/********************************************************************************/                  

CREATE PROC [dbo].[isp_BT_Bartender_SG_VCLABEL_LOGITECH]                        
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
   --SET ANSI_WARNINGS OFF                
                                
   DECLARE @n_intFlag            INT,       
           @n_CntRec             INT,      
           @c_SQL                NVARCHAR(4000),          
           @c_SQLSORT            NVARCHAR(4000),          
           @c_SQLJOIN            NVARCHAR(4000),  
           @c_ExecStatements     NVARCHAR(4000),         
           @c_ExecArguments      NVARCHAR(4000), 
                                 
           @n_TTLpage            INT,            
           @n_CurrentPage        INT,    
           @n_MaxLine            INT,  
           @n_Continue           INT,
           @c_WorkOrderkey       NVARCHAR(50),  
           @c_Storerkey          NVARCHAR(15),
           @c_JoinStatement      NVARCHAR(4000),
           @c_QRCode01           NVARCHAR(80),
           @c_QRCode02           NVARCHAR(80),
           @c_QRCode03           NVARCHAR(80),
           @c_QRCodeFull         NVARCHAR(240),
           @c_Data               NVARCHAR(100)
      
   DECLARE @c_EthernetMacAddr01  NVARCHAR(80), 
           @c_EthernetMacAddr02  NVARCHAR(80), 
           @c_EthernetMacAddr03  NVARCHAR(80), 
           @c_EthernetMacAddr04  NVARCHAR(80), 
           @c_WiFiMacAddr01      NVARCHAR(80), 
           @c_WiFiMacAddr02      NVARCHAR(80), 
           @c_WiFiMacAddr03      NVARCHAR(80),
           @c_WiFiMacAddr04      NVARCHAR(80),
           @c_SerialNo01         NVARCHAR(80),
           @c_SerialNo02         NVARCHAR(80),
           @c_SerialNo03         NVARCHAR(80),
           @c_SerialNo04         NVARCHAR(80),

           @c_EthernetMacAddr    NVARCHAR(80),
           @c_WiFiMacAddr        NVARCHAR(80),
           @c_SerialNo           NVARCHAR(80)
     
   SET @n_CurrentPage = 1    
   SET @n_TTLpage = 1         
   SET @n_MaxLine = 4       
   SET @n_CntRec = 1      
   SET @n_intFlag = 1     
   SET @c_JoinStatement = ''  
   SET @c_SQL = ''      
   SET @n_Continue = 1   
   SET @c_QRCodeFull = ''

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   WITH CTE AS (
   SELECT WkOrdUdef1 AS WkOrdUdef1, WkOrdUdef3 
   FROM WorkOrderDetail (NOLOCK)
   WHERE WorkOrderKey = @c_Sparm01
   AND WkOrdUdef4 = @c_Sparm02
   UNION ALL
   SELECT WkOrdUdef2 AS WkOrdUdef1, WkOrdUdef3 
   FROM WorkOrderDetail (NOLOCK)
   WHERE WorkOrderKey = @c_Sparm01
   AND WkOrdUdef4 = @c_Sparm02)
   SELECT CTE.WkOrdUdef1
   FROM CTE
   WHERE ISNULL(CTE.WkOrdUdef1,'') <> ''
   ORDER BY CASE WHEN ISNULL(CTE.WkOrdUdef3,'') = '' THEN 20 ELSE 10 END
          , CASE WHEN CTE.WkOrdUdef1 LIKE '__:__:__:__:__:__' THEN 10
                 WHEN ISNULL(CTE.WkOrdUdef1,'') <> '' THEN 20
                 ELSE 30 END ASC

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Data

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_QRCodeFull = @c_QRCodeFull + @c_Data + '|'

      FETCH NEXT FROM CUR_LOOP INTO @c_Data
   END 
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   
   IF LEN(@c_QRCodeFull) > 0
      SET @c_QRCode01 = SUBSTRING(TRIM(ISNULL(@c_QRCodeFull,'')), 1, 80)
   IF LEN(@c_QRCodeFull) > 80
      SET @c_QRCode02 = SUBSTRING(TRIM(ISNULL(@c_QRCodeFull,'')), 81, 80)
   IF LEN(@c_QRCodeFull) > 160
      SET @c_QRCode03 = SUBSTRING(TRIM(ISNULL(@c_QRCodeFull,'')), 161, 80)

   CREATE TABLE [#TEMPSKU] (                     
      [ID]              [INT] IDENTITY(1,1) NOT NULL,
      [WorkOrderkey]    [NVARCHAR] (80),
      [EthernetMacAddr] [NVARCHAR] (80) NULL, 
      [WiFiMacAddr]     [NVARCHAR] (80) NULL,             
      [SerialNo]        [NVARCHAR] (80) NULL, 
      [Retrieve]        [NVARCHAR] (1) DEFAULT 'N')
      
   INSERT INTO #TEMPSKU
   (
       WorkOrderkey,
       EthernetMacAddr,
       WiFiMacAddr,
       SerialNo,
       Retrieve
   )
   SELECT WOD.WorkOrderKey, WOD.WkOrdUdef2, WOD.WkOrdUdef3, WOD.WkOrdUdef1, 'N'
   FROM WorkOrderDetail WOD (NOLOCK)
   WHERE WOD.WorkOrderKey = @c_Sparm01
   AND WOD.WkOrdUdef4 = @c_Sparm02
   AND (TRIM(WOD.WkOrdUdef1 + WOD.WkOrdUdef2 + WOD.WkOrdUdef3) <> '')
   ORDER BY CASE WHEN ISNULL(WOD.WkOrdUdef2,'') = '' THEN 100 ELSE 1 END
          , CASE WHEN ISNULL(WOD.WkOrdUdef3,'') = '' THEN 110 ELSE 2 END
          , WOD.WorkOrderLineNumber

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
   
   SET @c_SQLJOIN = + ' SELECT TOP 1 '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --10
                    + ' '''', '''', ISNULL(@c_QRCode01,''''), ISNULL(@c_QRCode02,''''), ISNULL(@c_QRCode03,'''') ' + CHAR(13) --15
                    + ', '''', '''', '''', '''', '''', '  + CHAR(13) --20         
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --30     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --40  
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --50        
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', WOD.WorkOrderkey, ''SG'' ' + CHAR(13) --60
                    + ' FROM WorkOrderDetail WOD (NOLOCK) ' + CHAR(13)
                    + ' WHERE WOD.WorkOrderkey = @c_Sparm01 ' + CHAR(13)
                    + ' AND WOD.WkOrdUdef4 = @c_Sparm02 '

   IF @b_debug=1          
   BEGIN          
      PRINT @c_SQLJOIN            
   END                  
                
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13) +             
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13) +             
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54' + CHAR(13) +             
             +',Col55,Col56,Col57,Col58,Col59,Col60) '    
                  
   SET @c_SQL = @c_SQL + @c_SQLJOIN                
   
   SET @c_ExecArguments = N' @c_QRCode01         NVARCHAR(80) '
                        + ', @c_QRCode02         NVARCHAR(80) '
                        + ', @c_QRCode03         NVARCHAR(80) '
                        + ', @c_Sparm01          NVARCHAR(80) '
                        + ', @c_Sparm02          NVARCHAR(80) '

   EXEC sp_ExecuteSql  @c_SQL       
                     , @c_ExecArguments      
                     , @c_QRCode01     
                     , @c_QRCode02    
                     , @c_QRCode03  
                     , @c_Sparm01 
                     , @c_Sparm02
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END             

   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT Col59
      FROM #Result                         
               
      OPEN CUR_RowNoLoop                    
                  
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_WorkOrderkey
                    
      WHILE @@FETCH_STATUS <> -1               
      BEGIN  
         SET @c_EthernetMacAddr01 = ''
         SET @c_EthernetMacAddr02 = ''
         SET @c_EthernetMacAddr03 = ''
         SET @c_EthernetMacAddr04 = ''
         SET @c_WiFiMacAddr01     = ''
         SET @c_WiFiMacAddr02     = ''
         SET @c_WiFiMacAddr03     = ''
         SET @c_WiFiMacAddr04     = ''
         SET @c_SerialNo01        = ''
         SET @c_SerialNo02        = ''
         SET @c_SerialNo03        = ''
         SET @c_SerialNo04        = ''

         SELECT @n_CntRec = COUNT (1)  
         FROM #TEMPSKU   
         WHERE WorkOrderkey = @c_WorkOrderkey   
         AND Retrieve = 'N'   
           
         SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END   
      
         WHILE @n_intFlag <= @n_CntRec             
         BEGIN    
            IF @n_intFlag > @n_MaxLine AND (@n_intFlag % @n_MaxLine) = 1 --AND @c_LastRec = 'N'  
            BEGIN  
               SET @n_CurrentPage = @n_CurrentPage + 1  
           
               IF (@n_CurrentPage > @n_TTLpage)   
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
                            '','',Col13,Col14,Col15,'','','','','',                
                            '','','','','','','','','','',                
                            '','','','','','','','','','',                   
                            '','','','','','','','','','',                 
                            '','','','','','','','',Col59,Col60  
               FROM #Result     
       
               SET @c_EthernetMacAddr01 = ''
               SET @c_EthernetMacAddr02 = ''
               SET @c_EthernetMacAddr03 = ''
               SET @c_EthernetMacAddr04 = ''
               SET @c_WiFiMacAddr01     = ''
               SET @c_WiFiMacAddr02     = ''
               SET @c_WiFiMacAddr03     = ''
               SET @c_WiFiMacAddr04     = ''
               SET @c_SerialNo01        = ''
               SET @c_SerialNo02        = ''
               SET @c_SerialNo03        = ''
               SET @c_SerialNo04        = ''
            END      
      
            SELECT @c_EthernetMacAddr  = T.EthernetMacAddr
                 , @c_WiFiMacAddr      = T.WiFiMacAddr
                 , @c_SerialNo         = T.SerialNo
            FROM #TEMPSKU T
            WHERE ID = @n_intFlag  
              
            IF (@n_intFlag % @n_MaxLine) = 1
            BEGIN         
              SET @c_EthernetMacAddr01 = @c_EthernetMacAddr
              SET @c_WiFiMacAddr01 = @c_WiFiMacAddr
              SET @c_SerialNo01 = @c_SerialNo     
            END     
            ELSE IF (@n_intFlag % @n_MaxLine) = 2
            BEGIN         
              SET @c_EthernetMacAddr02 = @c_EthernetMacAddr
              SET @c_WiFiMacAddr02 = @c_WiFiMacAddr
              SET @c_SerialNo02 = @c_SerialNo             
            END  
            ELSE IF (@n_intFlag % @n_MaxLine) = 3
            BEGIN         
              SET @c_EthernetMacAddr03 = @c_EthernetMacAddr
              SET @c_WiFiMacAddr03 = @c_WiFiMacAddr
              SET @c_SerialNo03 = @c_SerialNo             
            END  
            ELSE IF (@n_intFlag % @n_MaxLine) = 0
            BEGIN         
              SET @c_EthernetMacAddr04 = @c_EthernetMacAddr
              SET @c_WiFiMacAddr04 = @c_WiFiMacAddr
              SET @c_SerialNo04 = @c_SerialNo          
            END    
               
            UPDATE #Result                    
            SET Col01 = @c_EthernetMacAddr01
              , Col02 = @c_WiFiMacAddr01
              , Col03 = @c_EthernetMacAddr02
              , Col04 = @c_WiFiMacAddr02
              , Col05 = @c_EthernetMacAddr03
              , Col06 = @c_WiFiMacAddr03
              , Col07 = @c_EthernetMacAddr04
              , Col08 = @c_WiFiMacAddr04
              , Col09 = @c_SerialNo01
              , Col10 = @c_SerialNo02
              , Col11 = @c_SerialNo03
              , Col12 = @c_SerialNo04
            WHERE ID = @n_CurrentPage   
      
            UPDATE #TEMPSKU
            SET Retrieve ='Y'  
            WHERE ID = @n_intFlag   
                         
            SET @n_intFlag = @n_intFlag + 1    
      
            IF @n_intFlag > @n_CntRec  
            BEGIN  
               BREAK;  
            END        
         END  
      
         FETCH NEXT FROM CUR_RowNoLoop INTO @c_WorkOrderkey          
      END -- While
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop  
   END
         
EXIT_SP: 
   SELECT * FROM #Result (NOLOCK)       
   ORDER BY ID 
        
   IF OBJECT_ID('tempdb..#TEMPSKU') IS NOT NULL
      DROP TABLE #TEMPSKU

   IF OBJECT_ID('tempdb..#Result') IS NOT NULL
      DROP TABLE #Result
                               
END -- procedure     

GO