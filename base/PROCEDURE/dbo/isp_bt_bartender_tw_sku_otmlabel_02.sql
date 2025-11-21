SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  

/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_TW_SKU_OTMLabel_02                               */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2022-04-11 1.0  Mingle     Created (WMS-19379)                             */   
/* 2022-04-11 1.0  Mingle     DevOps Combine Script                           */ 
/* 2022-09-23 1.1  Mingle     WMS-20793 Modify col04 logic(ML01)              */ 
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_TW_SKU_OTMLabel_02]                        
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
 --  SET ANSI_WARNINGS OFF                          
                                
   DECLARE                    
      @c_PLTKey      NVARCHAR(20),                      
      @c_DestWhs     NVARCHAR(20),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000)        
      
  DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),  
           @c_cust             NVARCHAR(60),  
           @c_Cust01           NVARCHAR(60),           
           @c_Cust02           NVARCHAR(60),           
           @c_Cust03           NVARCHAR(60),          
           @c_Cust04           NVARCHAR(60),         
           @c_Cust05           NVARCHAR(60),   
           @c_ExtOrdKey        NVARCHAR(60),       
           @c_ExtOrdKey01      NVARCHAR(60),          
           @c_ExtOrdKey02      NVARCHAR(60),           
           @c_ExtOrdKey03      NVARCHAR(60),          
           @c_ExtOrdKey04      NVARCHAR(60),           
           @c_ExtOrdKey05      NVARCHAR(60),  
           @c_CS               NVARCHAR(60),  
           @c_CS01             NVARCHAR(60),  
           @c_CS02             NVARCHAR(60),  
           @c_CS03             NVARCHAR(60),  
           @c_CS04             NVARCHAR(60),  
           @c_CS05             NVARCHAR(60),  
           @n_TTLpage          INT,          
           @n_CurrentPage      INT,  
           @n_MaxLine          INT  ,  
           @c_LLIId            NVARCHAR(80) ,  
           @c_storerkey        NVARCHAR(20) ,  
           @n_skuqty           INT ,  
           @n_RecCnt           INT  
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''       
    SET @n_CurrentPage = 1  
    SET @n_TTLpage =1       
    SET @n_MaxLine = 2     
    SET @n_CntRec = 1    
    SET @n_intFlag = 1     
    SET @n_RecCnt = 1      
                
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
       
       
      CREATE TABLE [#TEMPOTMSKU01] (                     
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                                        
      [Palletkey]   [NVARCHAR] (60) NULL,    
      [DESTWHS]     [NVARCHAR] (60) NULL,                    
      [CustName]    [NVARCHAR] (60) NULL,   
      [ExtOrdKey]   [NVARCHAR] (60) NULL,  
      [CS]          [NVARCHAR] (60) NULL,  
      [Retrieve]    [NVARCHAR] (1) default 'N')           
             
  SET @c_SQLJOIN = +' SELECT DISTINCT Q1.Palletkey,CK.description,Q2.TTLCS,'''','''','+ CHAR(13)      --5        
             + ' '''','''','''','''','''','     --10    
             + ' '''','''','''','''','''','     --15    
             + ' '''','''','''','''','''','     --20         
             + CHAR(13) +        
             + ' '''','''','''','''','''','''','''','''','''','''','  --30    
             + ' '''','''','''','''','''','''','''','''','''','''','   --40         
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
             + ' '''','''','''','''','''','''','''','''','''',''O'' '   --60            
             + CHAR(13) +              
          -- + ' FROM RECEIPT REC WITH (NOLOCK)'         
             + ' FROM '     
             + ' (SELECT AL1.PalletKey, SUBSTRING ( AL1.PalletKey, 3, 2 )as DTWHS, AL1.ExternOrderKey, '  
             --+ '  ISNULL ( AL3.SUSR3, AL1.Principal ) as CustName, AL1.UserDefine01 as CS'   +CHAR(13)  
             --+ '  ISNULL ( SUBSTRING(RTRIM(AL2.C_Company),1,5), AL1.Principal ) as CustName, AL1.UserDefine01 as CS'   +CHAR(13) --KEVIN 2019-01-23 
				 + '  CASE WHEN ISNULL(AL3.SUSR2,'''') <> '''' THEN AL3.SUSR2 ELSE left(AL2.c_company,5) + right(AL2.c_company,4) END as CustName, AL1.UserDefine01 as CS'   +CHAR(13) --KEVIN 2019-01-23	--ML01
             + ' FROM  OTMIDTrack AL1 WITH (NOLOCK)'   +CHAR(13)  
             + '  LEFT OUTER JOIN ORDERS AL2 WITH (NOLOCK) ON (AL1.ExternOrderKey=AL2.ExternOrderKey)' +CHAR(13)  
             + '  LEFT OUTER JOIN STORER AL3 WITH (NOLOCK)  ON (AL2.ConsigneeKey=AL3.StorerKey)  ' +CHAR(13)  
             + '  WHERE (AL1.PalletKey=''' + @c_Sparm01+ ''' )) AS Q1 ' +CHAR(13)  
             + '  LEFT Join '  +CHAR(13)  
             + ' (select palletkey,sum(cast (userdefine01 as numeric )) as TTLCS from otmidtrack WITH (NOLOCK) '  +CHAR(13)  
             + ' where palletkey=''' + @c_Sparm01+ '''  ' +CHAR(13)  
             + '  group by palletkey)  AS Q2 on Q1.Palletkey=Q2.Palletkey '     +CHAR(13)  
             + '  left join   '    +CHAR(13)  
             + ' codelkup CK WITH (nolock) on ck.code=Q1.DTWHS and CK.listname=''PLTDECODE'' '  
              
  
            
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
          
    EXEC sp_executesql @c_SQL            
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END    
     
           
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (NOLOCK)   
     -- GOTO EXIT_SP        
   END          
    
    
  DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
  SELECT DISTINCT col01,col02     
   FROM #Result                 
   WHERE Col60 = 'O'           
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_PLTKey,@c_destwhs      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_LLIId                   
      END   
        
        
      INSERT INTO [#TEMPOTMSKU01] (Palletkey,DESTWHS,CustName,ExtOrdKey,CS,Retrieve)  
      SELECT Q1.Palletkey,CK.description,Q1.CustName,Q1.Externorderkey,SUM(CAST(Q1.CS AS NUMERIC)),'N'  
      FROM  (SELECT AL1.PalletKey, SUBSTRING ( AL1.PalletKey, 3, 2 )AS DTWHS, AL1.ExternOrderKey  
           --,ISNULL ( NULLIF( AL3.SUSR3,''), AL1.Principal )  as CustName  
           -- ,ISNULL ( NULLIF( SUBSTRING(RTRIM(AL2.C_Company),1,5),''), AL1.Principal )  as CustName --KEVIN 2019-01-23  
			   , CASE WHEN ISNULL(AL3.SUSR2,'') <> '' THEN AL3.SUSR2 ELSE left(AL2.c_company,5) + right(AL2.c_company,4) END as CustName --KEVIN 2019-01-23	--ML01 
            , AL1.UserDefine01 AS CS  
            FROM  OTMIDTrack AL1 WITH (NOLOCK)  
            LEFT OUTER JOIN ORDERS AL2 WITH (NOLOCK)  ON (AL1.ExternOrderKey=AL2.ExternOrderKey)  
            LEFT OUTER JOIN STORER AL3 WITH (NOLOCK)   ON (AL2.ConsigneeKey=AL3.StorerKey)    
            WHERE (AL1.PalletKey=@c_PLTKey )) AS Q1   
    LEFT JOIN   
   (SELECT palletkey,SUM(CAST (userdefine01 AS NUMERIC )) AS TTLCS FROM otmidtrack WITH (NOLOCK)   
    WHERE palletkey=@c_PLTKey --and MUStatus='5'   
    GROUP BY palletkey)  AS Q2 ON Q1.Palletkey=Q2.Palletkey   
    LEFT JOIN codelkup CK WITH (NOLOCK) ON ck.code=Q1.DTWHS AND CK.listname='PLTDECODE'  
    GROUP BY Q1.Palletkey,CK.description,Q1.CustName,Q1.Externorderkey  
          
          
      SET @c_Cust01 = ''  
      SET @c_Cust02 = ''  
      SET @c_Cust03 = ''  
      SET @c_Cust04 = ''  
      SET @c_Cust05= ''  
      SET @c_ExtOrdKey01 = ''  
      SET @c_ExtOrdKey02 = ''  
      SET @c_ExtOrdKey03 = ''  
      SET @c_ExtOrdKey04 = ''  
      SET @c_ExtOrdKey05 = ''  
      SET @c_CS01 = ''  
      SET @c_CS02 = ''  
      SET @c_CS03 = ''  
      SET @c_CS04 = ''  
      SET @c_CS05 = ''  
           
      SELECT @n_CntRec = COUNT (1)  
      FROM #TEMPOTMSKU01  
      WHERE palletkey = @c_PLTKey  
      AND destwhs = @c_destwhs   
      AND Retrieve = 'N'   
       
      --SELECT * FROM #TEMPOTMSKU01  
      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )  
        
        
     WHILE @n_intFlag <= @n_CntRec             
     BEGIN     
        
      SELECT @c_cust = custname,  
             @c_extordkey = Extordkey,  
             @c_cs        = CS       
      FROM #TEMPOTMSKU01   
      WHERE ID = @n_intFlag  
      --GROUP BY SKU  
        
       IF (@n_intFlag%@n_MaxLine) = 1   
       BEGIN          
        SET @c_cust01      = @c_cust  
        SET @c_extordkey01 = @c_extordkey  
        SET @c_CS01        = @c_CS       
       END          
         
       ELSE IF (@n_intFlag%@n_MaxLine) = 2  
       BEGIN          
         SET @c_cust02      = @c_cust  
         SET @c_extordkey02 = @c_extordkey  
         SET @c_CS02        = @c_CS         
       END          
          
       ELSE IF (@n_intFlag%@n_MaxLine) = 3  
       BEGIN              
        SET @c_cust03      = @c_cust  
        SET @c_extordkey03 = @c_extordkey  
        SET @c_CS03        = @c_CS        
       END          
            
       ELSE IF (@n_intFlag%@n_MaxLine) = 4  
       BEGIN          
        SET @c_cust04      = @c_cust  
        SET @c_extordkey04 = @c_extordkey  
        SET @c_CS04        = @c_CS        
       END          
        
       ELSE IF (@n_intFlag%@n_MaxLine) = 0  
       BEGIN          
        SET @c_cust05      = @c_cust  
        SET @c_extordkey05 = @c_extordkey  
        SET @c_CS05        = @c_CS    
       END   
           
     IF (@n_RecCnt=@n_MaxLine) OR (@n_intFlag = @n_CntRec)  
     BEGIN    
       UPDATE #Result                    
       SET Col04 = @c_Cust01,           
           Col05 = @c_ExtOrdKey01,          
           Col06 = @c_CS01,                  
           Col07 = @c_Cust02,           
           Col08 = @c_ExtOrdKey02,           
           Col09 = @c_CS02,  
           Col10 = @c_Cust03,          
           Col11 = @c_ExtOrdKey03,          
           Col12 = @c_CS03,          
           Col13 = @c_Cust04,  
           Col14 = @c_ExtOrdKey04,          
           Col15 = @c_CS04,          
           Col16 = @c_Cust05,          
           Col17 = @c_ExtOrdKey05,          
           Col18 = @c_CS05          
       WHERE ID = @n_CurrentPage    
         
       --SELECT @n_intFlag '@n_intFlag'  
       --SELECT * FROM #TEMPOTMSKU01  
       --SELECT * FROM #Result  
       SET @n_RecCnt = 0  
     END   
       
         
   IF @n_RecCnt = 0 AND @n_intFlag<@n_CntRec --(@n_intFlag%@n_MaxLine) = 0 AND (@n_intFlag>@n_MaxLine)  
    BEGIN  
     SET @n_CurrentPage = @n_CurrentPage + 1  
       
     INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34   
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                            ,Col55,Col56,Col57,Col58,Col59,Col60)   
      SELECT TOP 1 Col01,Col02,Col03,'','', '','','','','',                   
                   '','','','','', '','','','','',                
                   '','','','','', '','','','','',                
                   '','','','','', '','','','','',                   
                   '','','','','', '','','','','',                 
                   '','','','','', '','','','',''  
      FROM  #Result   
      WHERE Col60='O'     
        
      SET @c_Cust01 = ''  
      SET @c_Cust02 = ''  
      SET @c_Cust03 = ''  
      SET @c_Cust04 = ''  
      SET @c_Cust05= ''  
      SET @c_ExtOrdKey01 = ''  
      SET @c_ExtOrdKey02 = ''  
      SET @c_ExtOrdKey03 = ''  
      SET @c_ExtOrdKey04 = ''  
      SET @c_ExtOrdKey05 = ''  
      SET @c_CS01 = ''  
      SET @c_CS02 = ''  
      SET @c_CS03 = ''  
      SET @c_CS04 = ''  
      SET @c_CS05 = ''    
        
     -- SELECT @n_intFlag '@n_intFlag',* FROM #Result                 
       
    END    
         
    SET @n_intFlag = @n_intFlag + 1     
    SET @n_RecCnt = @n_RecCnt + 1  
    --SET @n_CntRec = @n_CntRec - 1   
  
             
  END      
    
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_PLTKey,@c_destwhs      
          
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop     
          
SELECT * FROM #Result (nolock)          
              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_Bartender_TW_SKU_OTMLabel_02',    
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