SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_PALLETLBL_SG_GetParm                                */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-02-27 1.0  CSCHONG    Created (WMS-4102)                              */   
/* 2020-02-20 1.1  WLChooi    WMS-12122 - Add SKU as Parm03 (WL01)            */              
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_PALLETLBL_SG_GetParm]                      
(  @c_parm01            NVARCHAR(250),              
   @c_parm02            NVARCHAR(250),              
   @c_parm03            NVARCHAR(250),              
   @c_parm04            NVARCHAR(250),              
   @c_parm05            NVARCHAR(250),              
   @c_parm06            NVARCHAR(250),              
   @c_parm07            NVARCHAR(250),              
   @c_parm08            NVARCHAR(250),              
   @c_parm09            NVARCHAR(250),              
   @c_parm10            NVARCHAR(250),        
   @b_debug             INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
   --SET ANSI_WARNINGS OFF                      
                              
   DECLARE                  
      @c_ReceiptKey       NVARCHAR(10),                    
      @c_ExternOrderKey   NVARCHAR(10),              
      @c_Deliverydate     DATETIME,              
      @n_intFlag          INT,     
      @n_CntRec           INT,    
      @c_SQL              NVARCHAR(4000),        
      @c_SQLSORT          NVARCHAR(4000),        
      @c_SQLJOIN          NVARCHAR(4000),
      @c_SQLCOND1         NVARCHAR(4000),
      @c_SQLCOND2         NVARCHAR(4000),
      @c_ExecStatements   NVARCHAR(4000),    
      @c_ExecArguments    NVARCHAR(4000),    
      @c_SQLOrdBy         NVARCHAR(150)       
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @n_cntsku           INT,
           @c_mode             NVARCHAR(1),
           @c_sku              NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30)     
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''   
    SET @c_mode = '0'   
    SET @c_SQLCOND1 = ''
    SET @c_SQLCOND1 = ''  
    SET @c_SQLOrdBy = ''    
   
   SET @c_SQLJOIN=N'SELECT DISTINCT PARM1=RECDET.Receiptkey, PARM2=RECDET.toid,PARM3=ISNULL(@c_parm03,'''') ' +CHAR(13)   --WL01
                 + ',PARM4='''',PARM5='''',PARM6='''',PARM7='''',PARM8='''',PARM9='''',PARM10='''' ' +CHAR(13)
                 + ',Key1=''ReceiptKey'',Key2=''ToID'',Key3='''',Key4='''',Key5=''''  ' +CHAR(13)
                 + ' FROM RECEIPTDETAIL RECDET WITH (NOLOCK) ' +CHAR(13)

   IF @c_parm01 <> ''
   BEGIN
      IF @c_parm02 <> ''
      BEGIN
         SET @c_SQLCOND1 = 'WHERE RECDET.receiptkey = @c_parm01 AND RECDET.toid = @c_parm02 ' +CHAR(13)
      END
      ELSE
      BEGIN
         SET @c_SQLCOND1 = 'WHERE RECDET.receiptkey = @c_parm01' +CHAR(13)
      END	
   END
   ELSE IF @c_parm02 <> ''
   BEGIN
      SET @c_SQLCOND1 = 'WHERE RECDET.toid = @c_parm02 ' +CHAR(13)
   END
	 	
   SET @c_SQLCOND2 =' AND RECDET.toid <> '''' ' + CHAR(13)
 
   SET @c_SQLOrdBy = ' ORDER BY RECDET.receiptkey,RECDET.toid '
	 	
   SET @c_SQL = @c_SQLJOIN + @c_SQLCOND1 + @c_SQLCOND2+ @c_SQLOrdBy
	 	 
   PRINT @c_SQL
	 	 
   SET @c_ExecArguments = N'  @c_parm01     NVARCHAR(80)'    
                         + ', @c_parm02     NVARCHAR(80) '    
                         + ', @c_parm03     NVARCHAR(80) '    --WL01
                          
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_parm01   
                        , @c_parm02  
                        , @c_parm03  --WL01 
                  
            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                     
   END -- procedure   


GO