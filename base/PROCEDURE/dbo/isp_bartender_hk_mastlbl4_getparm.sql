SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_HK_MASTLBL4_GetParm                                 */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2019-05-13 1.0  CSCHONG    Created (WMS-8877)                              */    
/* 2019-06-10 1.1  CSCHONG    Fix PROD issue (WMS-8877) (CS01a)               */   
/* 2019-08-19 1.2  WLChooi    WMS-10208 - Modify conditions (WL01)            */           
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_HK_MASTLBL4_GetParm]                      
(  @parm01            NVARCHAR(250),              
   @parm02            NVARCHAR(250),              
   @parm03            NVARCHAR(250),              
   @parm04            NVARCHAR(250),              
   @parm05            NVARCHAR(250),              
   @parm06            NVARCHAR(250),              
   @parm07            NVARCHAR(250),              
   @parm08            NVARCHAR(250),              
   @parm09            NVARCHAR(250),              
   @parm10            NVARCHAR(250),        
   @b_debug             INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
                     
                              
   DECLARE                  
      @c_StorerKey       NVARCHAR(20),                    
      @c_Labelno         NVARCHAR(20),                           
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(MAX), 
      @c_SQLInsert       NVARCHAR(4000),       
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_condition3      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_ExecArguments   NVARCHAR(4000)
      
    
  DECLARE @d_Trace_StartTime   DATETIME,   
          @d_Trace_EndTime    DATETIME,  
          @c_Trace_ModuleName NVARCHAR(20),   
          @d_Trace_Step1      DATETIME,   
          @c_Trace_Step1      NVARCHAR(20),  
          @c_UserName         NVARCHAR(20),
          @c_sku              NVARCHAR(20),
          @c_data             NVARCHAR(20),
          @n_qty              INT,
          @n_Maxcopy          INT,
          @n_NoCopy           INT,
          @n_LENDATA          INT,
          @c_PrintbySKU       NVARCHAR(1)

  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
   SET @n_qty = 1
   SET @c_PrintbySKU = 'N'
        
    -- SET RowNo = 0             
   SET @c_SQL = ''   
   SET @c_SQLJOIN = ''  
   SET @n_NoCopy = 1
   SET @n_Maxcopy = 500
   
 CREATE TABLE #TEMPRESULT  (
     PARM01       NVARCHAR(80),  
     PARM02       NVARCHAR(80),  
     PARM03       NVARCHAR(80),  
     PARM04       NVARCHAR(80),  
     PARM05       NVARCHAR(80),  
     PARM06       NVARCHAR(80),  
     PARM07       NVARCHAR(80),  
     PARM08       NVARCHAR(80),  
     PARM09       NVARCHAR(80),  
     PARM10       NVARCHAR(80),  
     Key01        NVARCHAR(80),
     Key02        NVARCHAR(80),
     Key03        NVARCHAR(80),
     Key04        NVARCHAR(80),
     Key05        NVARCHAR(80)
     
    )
   IF ISNULL(@parm03,'') <> ''
   BEGIN
    --IF NOT EXISTS (SELECT 1 FROM PACKDETAIL WITH (NOLOCK)             --CS01a
    --               WHERE Storerkey = @Parm01 AND SKU = @parm03)
    -- BEGIN
      
      IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK)
                 WHERE Storerkey = @Parm01 AND SKU = @parm03)
       BEGIN
         SET @c_PrintbySKU = 'Y'
      END
      ELSE
      BEGIN
        GOTO EXIT_SP
      END
 --   END                  --CS01a
  END
         
    
    SET @c_SQLInsert = ''
    SET @c_SQLInsert ='INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, ' + CHAR(13) +
                     ' Key01,Key02,Key03,Key04,Key05)'   
   
   IF ISNULL(@Parm02,'') <>''
   BEGIN
      SET @c_condition1 = N' AND PD.Labelno = @Parm02'
   END  

   IF ISNULL(@Parm03,'') <>''
   BEGIN
     IF @c_PrintbySKU = 'N'
     BEGIN
        SET @c_condition2 = N' AND PD.SKU = @Parm03 '
      END
     ELSE
     BEGIN
       SET @c_condition2 = N' AND S.SKU = @Parm03 '
     END
   END  

   IF ISNULL(@Parm04,'') <>''
   BEGIN
      SET @n_qty = CAST(@Parm04 AS INT)
   END  

   IF @c_PrintbySKU = 'N'
   BEGIN
      SET @c_SQLOrdBy = N' ORDER BY PD.storerkey,PD.SKU  '
   END
   ELSE
   BEGIN
      SET @c_SQLOrdBy = N' ORDER BY S.storerkey,S.SKU  '
   END

   IF @c_PrintbySKU = 'N'
   BEGIN
       SET @c_SQLGroup = N' GROUP BY PD.storerkey,PD.SKU,ISNULL(RTRIM(DIF.DATA),''''),s.altsku,SIF.ExtendedField01,PD.labelno,PD.qty,S.SUSR1 ' + CHAR(13) + --WL01
                          ' HAVING (LEN(ISNULL(RTRIM(DIF.DATA),'''')) <= 76 AND S.SUSR1 <> ''ACC'') OR   ' + CHAR(13) +   --WL01
                          ' (LEN(ISNULL(RTRIM(DIF.DATA),'''')) BETWEEN 1 AND 76 AND S.SUSR1 = ''ACC'' ) '                 --WL01
    END
   ELSE
   BEGIN
     SET @c_SQLGroup = N' GROUP BY S.storerkey,S.SKU,ISNULL(RTRIM(DIF.DATA),''''),s.altsku,SIF.ExtendedField01,S.SUSR1 ' + CHAR(13) +  --WL01
                        ' HAVING (LEN(ISNULL(RTRIM(DIF.DATA),'''')) <= 76 AND S.SUSR1 <> ''ACC'') OR   ' + CHAR(13) +   --WL01
                        ' (LEN(ISNULL(RTRIM(DIF.DATA),'''')) BETWEEN 1 AND 76 AND S.SUSR1 = ''ACC'' ) '                 --WL01
   END


   IF @c_PrintbySKU = 'N'
   BEGIN
        SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=PD.storerkey,PARM2= PD.SKU,PARM3=ISNULL(RTRIM(DIF.DATA),''''),PARM4=s.altsku,PARM5=SIF.ExtendedField01,' + CHAR(13) +
                     ' PARM6= PD.labelno,PARM7=CASE WHEN ISNULL(@Parm04,'''') <>'''' THEN CAST(@n_qty as nvarchar(5)) ELSE PD.qty END,' + CHAR(13) +
                     ' PARM8='''',PARM9='''',PARM10='''',Key1=''Storerkey'',Key2=''sku'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +
                     ' FROM PACKDETAIL PD WITH (NOLOCK)  ' + CHAR(13) +
                     ' LEFT JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey AND S.SKU = PD.SKU ' + CHAR(13) +
                     ' LEFT JOIN SKUINFO SIF WITH (NOLOCK) ON SIF.SKU = S.SKU AND SIF.Storerkey = S.Storerkey ' + CHAR(13) +
                     ' LEFT JOIN Docinfo DIF WITH (NOLOCK) ON DIF.Key2 = SIF.ExtendedField03 and DIF.Storerkey = SIF.Storerkey ' + CHAR(13) +
                     '  AND DIF.TableName = ''SKU'' ' + CHAR(13) +
                     ' WHERE PD.storerkey = @Parm01 '  + CHAR(13)
    END
   ELSE
   BEGIN
     SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=S.storerkey,PARM2= S.SKU,PARM3=ISNULL(RTRIM(DIF.DATA),''''),PARM4=s.altsku,PARM5=SIF.ExtendedField01,' + CHAR(13) +
                     ' PARM6= '''',PARM7=CASE WHEN ISNULL(@Parm04,'''') <>'''' THEN CAST(@n_qty as nvarchar(5)) ELSE 1 END,' + CHAR(13) +
                     ' PARM8='''',PARM9='''',PARM10='''',Key1=''Storerkey'',Key2=''sku'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +
                     ' FROM SKU S WITH (NOLOCK) ' + CHAR(13) +
                     ' LEFT JOIN SKUINFO SIF WITH (NOLOCK) ON SIF.SKU = S.SKU AND SIF.Storerkey = S.Storerkey ' + CHAR(13) +
                     ' LEFT JOIN Docinfo DIF WITH (NOLOCK) ON DIF.Key2 = SIF.ExtendedField03 and DIF.Storerkey = SIF.Storerkey ' + CHAR(13) +
                     '  AND DIF.TableName = ''SKU'' ' + CHAR(13) +
                     ' WHERE S.storerkey = @Parm01 '  + CHAR(13)
   END
    
        SET @c_ExecArguments = N'@parm01          NVARCHAR(80),'
                             + ' @parm02          NVARCHAR(80),' 
                             + ' @parm03          NVARCHAR(80),'
                             + ' @parm04          NVARCHAR(80),'
                             + ' @parm05          NVARCHAR(80),'
                             + ' @n_qty           INT'
                       
       
       SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_SQLGroup + CHAR(13) + @c_SQLOrdBy
      
      
    EXEC sp_executesql   @c_SQL  
                       , @c_ExecArguments  
                       , @parm01  
                       , @parm02 
                       , @parm03 
                       , @parm04
                       , @parm05
                       , @n_qty

    --WL01
    IF @b_debug = 1
       PRINT @c_SQL

    IF @n_qty > @n_Maxcopy
      BEGIN
         GOTO EXIT_SP
      END

 /*  DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT PARM01,PARM02,PARM06,PARM03   
   FROM   #TEMPRESULT 
   WHERE PARM01 = @parm01   
   ORDER BY PARM01,PARM02
  
   OPEN CUR_RowNoLoop   
     
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_storerkey,@c_sku,@c_labelno,@c_data   
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 
   SET @n_NoCopy = @n_qty

  /* IF LEN(@c_data) > 76
   BEGIN
     DELETE #TEMPRESULT 
    WHERE PARM01 = @c_storerkey
    AND PARM02=@c_sku
    AND PARM06 = @c_labelno
   END
   ELSE
   BEGIN*/
   UPDATE #TEMPRESULT
   SET PARM03 = ''
   WHERE PARM01 = @c_storerkey
    AND PARM02=@c_sku
    AND PARM06 = @c_labelno

    WHILE @n_NoCopy >= 2
     BEGIN
     INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, 
                      Key01,Key02,Key03,Key04,Key05)
      SELECT TOP 1 PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,
                  Key01,Key02,Key03,Key04,Key05
      FROM  #TEMPRESULT
      WHERE PARM01 = @c_storerkey 
      AND PARM02 = @c_sku
      AND PARM06 = @c_labelno

   SET @n_NoCopy = @n_NoCopy -1
   --END
 END


   FETCH NEXT FROM CUR_RowNoLoop INTO @c_storerkey,@c_sku,@c_labelno,@c_data
   END
   CLOSE CUR_RowNoLoop                  
   DEALLOCATE CUR_RowNoLoop  
   */

     SELECT PARM01,  
          PARM02, 
          '' as PARM03, 
          PARM04, 
          PARM05, 
          PARM06, 
          PARM07, 
          PARM08, 
          PARM09, 
          PARM10, 
          Key01 ,   
          Key02 ,   
          Key03 ,   
          Key04 ,   
          Key05     
   FROM #TEMPRESULT
   ORDER BY PARM01,PARM02,PARM06
                       
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  

                                  
   END -- procedure   



GO