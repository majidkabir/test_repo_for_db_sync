SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: isp_Bartender_TW_SHIPLBL002_GetParm                               */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date         Rev  Author     Purposes                                      */                                          
/******************************************************************************/                    
                      
CREATE PROC [dbo].[isp_Bartender_TW_SHIPLBL002_GetParm]                          
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
   @b_debug           INT = 0                             
)                          
AS                          
BEGIN                          
   SET NOCOUNT ON                     
   SET ANSI_NULLS OFF                    
   SET QUOTED_IDENTIFIER OFF                     
   SET CONCAT_NULL_YIELDS_NULL OFF                    
                                  
   DECLARE                      
      @c_ReceiptKey      NVARCHAR(10),                        
      @c_ExternOrderKey  NVARCHAR(10),                  
      @c_Deliverydate    DATETIME,                  
      @n_intFlag         INT,         
      @n_CntRec          INT,        
      @c_SQL             NVARCHAR(4000), 
      @c_SQLInsert       NVARCHAR(4000),             
      @c_SQLSORT         NVARCHAR(4000),            
      @c_SQLJOIN         NVARCHAR(4000),    
      @c_condition1      NVARCHAR(150) ,    
      @c_condition2      NVARCHAR(150),    
      @c_SQLGroup        NVARCHAR(4000),    
      @c_SQLOrdBy        NVARCHAR(150),
      @c_storerkey       NVARCHAR(20),
      @n_Maxcopy         INT,
      @n_NoCopy          INT    
          
        
  DECLARE  @d_Trace_StartTime   DATETIME,       
           @d_Trace_EndTime    DATETIME,      
           @c_Trace_ModuleName NVARCHAR(20),       
           @d_Trace_Step1      DATETIME,       
           @c_Trace_Step1      NVARCHAR(20),      
           @c_UserName         NVARCHAR(20),    
           @c_ExecStatements   NVARCHAR(4000),        
           @c_ExecArguments    NVARCHAR(4000),
           @n_Counter          INT = 1            
      
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_Trace_ModuleName = ''      
            
    -- SET RowNo = 0                 
   SET @c_SQL = ''       
   SET @c_SQLJOIN = ''            
   SET @c_condition1 = ''    
   SET @c_condition2= ''    
   SET @c_SQLOrdBy = ''    
   SET @c_SQLGroup = ''    
   SET @c_ExecStatements = ''    
   SET @c_ExecArguments = '' 
   SET @c_storerkey = '' 
   SET @n_NoCopy = 1
   
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
    
   SET @c_SQLInsert = ''
   SET @c_SQLInsert ='INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, ' + CHAR(13) +
                     ' Key01,Key02,Key03,Key04,Key05)'
      
     
   IF EXISTS (SELECT 1 FROM PICKDETAIL PD WITH (NOLOCK) WHERE PD.dropid=@Parm01) AND ISNULL(@Parm02,'') = ''
   BEGIN     
      SET @c_SQLJOIN = 'SELECT DISTINCT PARM1= PD.Dropid,PARM2=PD.orderkey,PARM3= '''' ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+    
                       'PARM8='''',PARM9='''',PARM10='''',Key1=''dropid'',Key2=''orderkey'',Key3='''',' +    
                       ' Key4='''','+    
                       ' Key5= '''' '  +      
                       ' FROM PICKDETAIL PD WITH (NOLOCK) ' +         
                       ' WHERE PD.Dropid = @Parm01 ' 
   --  SET @c_SQL = @c_SQLJOIN 
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK) WHERE OH.Orderkey = @Parm01) 
   BEGIN
      IF ISNULL(@Parm02,'') <> ''
      BEGIN
         SET @n_NoCopy = CAST(@Parm02 as int)
         SET @n_Maxcopy = 300
     
         SELECT @c_storerkey = OH.Storerkey
         FROM ORDERS OH WITH (NOLOCK)
         WHERE OH.OrderKey = @Parm01

         SELECT @n_Maxcopy = CAST(C.short as int) 
         FROM CODELKUP C WITH (NOLOCK)
         WHERE LISTNAME = 'MaxNoCopy'
         AND Code = 'NoOfCopy'
         AND Storerkey = @c_storerkey

         IF @n_maxcopy = 0
         BEGIN
            SET @n_Maxcopy = 300
         END

         IF @n_NoCopy > @n_Maxcopy
         BEGIN
            GOTO EXIT_SP
         END
      END
      --print '1'
      SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=OH.Storerkey,PARM2=OH.orderkey,PARM3= ''1'' ,PARM4= @parm02,PARM5='''',PARM6='''',PARM7='''', '+    --CS01
                       ' PARM8='''',PARM9='''',PARM10='''',Key1=''Orderkey'',Key2='''',Key3='''',' +    
                       ' Key4='''','+    
                       ' Key5= '''' '  +      
                       ' FROM ORDERS OH WITH (NOLOCK) ' + --CS01
                       ' WHERE OH.Orderkey = @Parm01 ' 
     --END
   END
           
   SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN  
   --PRINT  @c_SQLJOIN   
         
    --EXEC sp_executesql @c_SQL        
        
   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80)'        
                          + ', @parm02           NVARCHAR(80) '        
                          + ', @parm03           NVARCHAR(80)'       
                                  
   EXEC sp_ExecuteSql     @c_SQL         
                        , @c_ExecArguments        
                        , @parm01        
                        , @parm02       
                        , @parm03  
                  
   WHILE @n_NoCopy >= 2
   BEGIN
      SET @n_Counter = @n_Counter + 1

      INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, 
                               Key01,Key02,Key03,Key04,Key05)
      SELECT TOP 1 PARM01,PARM02,@n_Counter,@parm02,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,
                   Key01,Key02,Key03,Key04,Key05
      FROM #TEMPRESULT

      SET @n_NoCopy = @n_NoCopy - 1
   END

   SELECT * FROM #TEMPRESULT
              
EXIT_SP:        
      
   SET @d_Trace_EndTime = GETDATE()      
   SET @c_UserName = SUSER_SNAME()      
                                      
END -- procedure 

GO