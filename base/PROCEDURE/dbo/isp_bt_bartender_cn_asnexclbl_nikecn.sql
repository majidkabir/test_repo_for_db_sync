SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                       
/* Copyright: LFL                                                             */                       
/* Purpose: isp_BT_Bartender_CN_ASNEXCLBL_NIKECN                              */                       
/*                                                                            */                       
/* Modifications log:                                                         */                       
/*                                                                            */                       
/* Date       Rev  Author     Purposes                                        */      
/*17-May-2021 1.0  WLChooi    Created (WMS-17019)                             */ 
/*09-Jun-2021 1.1  WLChooi    Performance Tune (WL01)                         */   
/*12-Oct-2021 1.2  Mingle     Add new logic (ML01)                            */  
/******************************************************************************/                      
                        
CREATE PROC [dbo].[isp_BT_Bartender_CN_ASNEXCLBL_NIKECN]                            
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
                                         
   DECLARE @c_SQL               NVARCHAR(4000),  
           @d_Trace_StartTime   DATETIME,         
           @d_Trace_EndTime     DATETIME,        
           @c_Trace_ModuleName  NVARCHAR(20),         
           @d_Trace_Step1       DATETIME,        
           @c_Trace_Step1       NVARCHAR(20),        
           @c_UserName          NVARCHAR(20),               
           @c_ExecArguments     NVARCHAR(4000),
           @c_SQLJOIN           NVARCHAR(MAX),
           @c_Col02             NVARCHAR(80),
           @c_DSTCol01          NVARCHAR(80),
           @c_Storerkey         NVARCHAR(15)
          

   DECLARE @dt_UserDefine06     DATETIME
         , @dt_TodayDate        DATETIME
         , @n_DiffInDay         INT
         , @c_UserDefine02      NVARCHAR(60)   --ML01

   DECLARE @c_TableName         NVARCHAR(20) = 'ASNEXCEPTION'   --WL01
   
   SET @d_Trace_StartTime = GETDATE()        
   SET @c_Trace_ModuleName = ''        
              
    -- SET RowNo = 0  
   SET @c_SQL = ''                 
   SET @c_SQLJOIN = ''   
   SET @c_ExecArguments = ''
   
   SELECT @c_DSTCol01  = DST.UserDefine01
        , @c_Storerkey = DST.StorerKey
   FROM DocStatusTrack DST (NOLOCK)      
   WHERE DST.DocumentNo = @c_Sparm01
   AND DST.TableName = @c_TableName   --WL01 

   IF EXISTS (SELECT TOP 1 1 
              FROM RDT.RDTDataCapture RDC (NOLOCK) 
              WHERE RDC.V_String1 = @c_DSTCol01
              AND RDC.Storerkey = @c_Storerkey)
   BEGIN
      SELECT @c_Col02 = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_Col02 = 'N'
   END

   --WL01 S
   --SELECT @dt_UserDefine06 = MIN(R.UserDefine06) 
   --FROM DocInfo DI (NOLOCK)
   --LEFT JOIN DocStatusTrack DST (NOLOCK) ON DST.Userdefine01 = DI.Key3 AND DST.StorerKey = DI.StorerKey
   --JOIN RECEIPT R (NOLOCK) ON R.ReceiptKey = DI.Key1
   --WHERE DI.TableName = 'RECEIPT'
   --AND DST.DocumentNo = @c_Sparm01

   SELECT @dt_UserDefine06 = MIN(R.UserDefine06),@c_UserDefine02 = MIN(R.UserDefine02) --ML01
   FROM DocInfo DI (NOLOCK)
   JOIN DocStatusTrack DST (NOLOCK) ON DST.Userdefine01 = DI.Key3 AND DST.StorerKey = DI.StorerKey
   JOIN RECEIPT R (NOLOCK) ON R.ReceiptKey = DI.Key1
   WHERE DI.TableName = 'RECEIPT'
   AND DST.DocumentNo = @c_Sparm01
   AND DST.TableName = @c_TableName
 
 
   --WL01 E
   
   SET @dt_TodayDate    = CONVERT(DATE, GETDATE())
   SET @dt_UserDefine06 = CONVERT(DATE, @dt_UserDefine06)
   
   
   SELECT @n_DiffInDay = DATEDIFF(DAY, @dt_UserDefine06, @dt_TodayDate)
   

   IF @b_debug = 1
      SELECT @dt_TodayDate, @dt_UserDefine06, @n_DiffInDay

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
              

   --SET @c_SQLJOIN = + ' SELECT DISTINCT TOP 1 CASE WHEN DST.UserDefine08 = ''Y'' THEN ''Tmall'' ' + CHAR(13)
   --                 + '                            WHEN DST.UserDefine08 = ''N'' THEN ''.com''  ' + CHAR(13)
   --                 + '                            ELSE '''' END, ' + CHAR(13)
   SET @c_SQLJOIN =   + ' SELECT DISTINCT TOP 1 ISNULL(CL1.long,''''), ' + CHAR(13)    --ML01     
                    + ' @c_Col02, ISNULL(DST.UserDefine03,''''), DST.DocumentNo, ISNULL(DST.UserDefine01,''''), ' + CHAR(13)   --5             
                    + ' ISNULL(DST.UserDefine05,''''), ISNULL(CL.[Description],''''), REPLACE(CONVERT(NVARCHAR(20), DST.UserDefine06, 120), ''-'', ''/''), ' + CHAR(13)
                    +N' DST.AddWho, CASE WHEN @n_DiffInDay >= 9 THEN N''加急'' ELSE '''' END, ' + CHAR(13)   --10    
                    +N' CASE WHEN @c_UserDefine02 = ''Y'' THEN N''绿通'' ELSE '''' END, ' + CHAR(13)    --ML01
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --20     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --30     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --40        
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --50                           
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', @c_Sparm01 ' + CHAR(13)  --60                
                    + ' FROM DocStatusTrack DST (NOLOCK) ' + CHAR(13)
                    + ' LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Storerkey = DST.Storerkey ' + CHAR(13)
                    + '                               AND CL.ListName = ''O2Reason'' ' + CHAR(13)
                    + '                               AND CL.Code = DST.UserDefine02 ' + CHAR(13)
                    + ' LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.Storerkey = DST.Storerkey ' + CHAR(13)
                    + '                                AND CL1.ListName = ''NKEXC'' ' + CHAR(13)
                    + '                                AND CL1.UDF04 = DST.UserDefine08 ' + CHAR(13)    --ML01
                    + ' WHERE DST.DocumentNo = @c_Sparm01 AND DST.TableName = ''ASNEXCEPTION'' '     

   IF @b_debug=1              
   BEGIN              
      PRINT @c_SQLJOIN                
   END                      
                   
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +                 
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +                 
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +                 
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +                 
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +                 
             +',Col55,Col56,Col57,Col58,Col59,Col60) '                
          
   SET @c_SQL = @c_SQL + @c_SQLJOIN          
      
   SET @c_ExecArguments = N'  @c_Sparm01          NVARCHAR(80) '          
                         + ', @c_Sparm02          NVARCHAR(80) '      
                         + ', @c_Sparm03          NVARCHAR(80) ' 
                         + ', @c_Sparm04          NVARCHAR(80) ' 
                         + ', @c_Sparm05          NVARCHAR(80) ' 
                         + ', @c_Col02            NVARCHAR(80) '  
                         + ', @n_DiffInDay        NVARCHAR(80) ' 
                         + ', @c_UserDefine02     NVARCHAR(80) '  --ML01
                                          
   EXEC sp_ExecuteSql     @c_SQL           
                        , @c_ExecArguments          
                        , @c_Sparm01         
                        , @c_Sparm02     
                        , @c_Sparm03   
                        , @c_Sparm04   
                        , @c_Sparm05   
                        , @c_Col02
                        , @n_DiffInDay
                        , @c_UserDefine02  --ML01
   IF @b_debug = 1              
   BEGIN                
      PRINT @c_SQL                
   END        
                 
   SELECT * FROM #Result (nolock)            
                  
EXIT_SP:            
   SET @d_Trace_EndTime = GETDATE()        
   SET @c_UserName = SUSER_SNAME()        
                              
END -- procedure

GO