SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_PALLETLBL4_GetParm                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-10-23 1.1  CSCHONG    WMS-3566 - created                              */                           
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_PALLETLBL4_GetParm]                      
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
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_SQLinsert       NVARCHAR(4000) ,  
      @c_SQLSelect       NVARCHAR(4000),
      @c_printbyRec      NVARCHAR(1),
      @c_printbyLLI      NVARCHAR(1)   
      
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000),
           @c_storerkey        NVARCHAR(20),
           @n_Pqty             INT,   
           @n_rowno            INT   
  
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
    SET @c_SQLinsert = ''
    SET @c_SQLSelect = ''
    SET @c_printbyRec = 'N'
    SET @c_printbyLLI = 'N'


    IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK)
               WHERE containerkey = @parm01)
     BEGIN
        SET @c_printbyRec = 'Y'
        SET @c_condition1 = ' WHERE R.Storerkey = @parm02 and R.Containerkey = @parm01 ' 
        SET @c_SQLOrdBy = 'Order by R.receiptkey,RD.toid,RD.sku'
    END
    ELSE IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK)
               WHERE receiptkey = @parm01) 

     BEGIN
       
        SET @c_printbyRec = 'Y'
        SET @c_condition1 = ' WHERE R.Storerkey = @parm02 and R.Receiptkey = @parm01'
        SET @c_SQLOrdBy = 'Order by R.receiptkey,RD.toid,RD.sku'

    END


    IF @c_printbyRec = 'Y'
    BEGIN
    SET @c_SQLJOIN = 'SELECT DISTINCT PARM1=R.receiptkey, ' +
                  ' PARM2=RD.toid,PARM3= RD.sku ,PARM4= R.storerkey,PARM5='''',PARM6='''',PARM7='''', '+
                  'PARM8='''',PARM9='''',PARM10=''1'',Key1=''receiptkey'',Key2='''',Key3='''',Key4='''','+
                  ' Key5= '''' '  +  
                  ' FROM Receipt R WITH (nolock) ' + 
                  ' JOIN Receiptdetail RD WITH (NOLOCK) ON RD.receiptkey = R.receiptkey'
                     
       SET @c_SQL = @c_SQLJOIN + @c_condition1
      
       SET @c_ExecArguments = N'   @parm01           NVARCHAR(80),' +
                               '   @parm02           NVARCHAR(80),' +
                               '   @parm03           NVARCHAR(80)'      

                                           
   EXEC sp_ExecuteSql    @c_SQL     
                       , @c_ExecArguments    
                       , @parm01    
                       , @parm02
                       , @parm03
      
 END  
 ELSE 
 BEGIN
 SET @c_SQLJOIN = 'SELECT PARM1=lli.id, ' +       
            ' PARM2=lli.sku,PARM3= lli.storerkey ,PARM4= SUM(lli.qty),PARM5='''',PARM6='''',PARM7='''', '+
            ' PARM8='''',PARM9='''',PARM10=''2'',Key1=''receiptkey'',Key2='''',Key3='''',Key4='''','+
            ' Key5= '''' '  +  
            ' FROM LotxLocxID LLI WITH (nolock) ' + 
            ' where lli.Storerkey = @parm02 and lli.id =@parm01 ' +  
             'Group by lli.id,lli.sku,lli.storerkey ' +  
             'Order by  lli.id,lli.sku'
            
       SET @c_SQL = @c_SQLJOIN 
    

   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80),' +
                           '   @parm02           NVARCHAR(80),' +
                           '   @parm03           NVARCHAR(80)'      

                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                  , @c_ExecArguments    
                  , @parm01    
                  , @parm02
                  , @parm03

 END                    
 --select * from #TEMP_PICKBYQTY

            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO