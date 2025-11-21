SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_CN_Bartender_RETAILLBL_GetParm                                */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-02-22 1.0  CSCHONG    Created(WMS-3953)                               */                 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_CN_Bartender_RETAILLBL_GetParm]                      
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
      @c_ReceiptKey        NVARCHAR(10),                    
      @c_ExternOrderKey  NVARCHAR(10),              
      @c_Deliverydate    DATETIME,              
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_ExecArguments   NVARCHAR(4000)
      
    
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
    SET @c_getUCCno = ''
    SET @c_getUdef09 = ''  
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
       
    SET @c_ExecArguments = ''

    SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=PAH.storerkey,PARM2=PAH.Pickslipno,PARM3=CAST(PADET.CartonNo as NVARCHAR(20)),PARM4=CAST(PADET.CartonNo as NVARCHAR(20)),PARM5='''',' + CHAR(13) +
                     ' PARM6='''',PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1=''storerkey'',Key2=''Pickslipno'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +
                     ' FROM PACKHEADER PAH WITH (NOLOCK) ' + CHAR(13) +
                     ' JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno ' + CHAR(13) +
                     ' WHERE PAH.Storerkey = @parm01 ' + CHAR(13) +
                     ' AND PAH.Pickslipno = @parm02' + CHAR(13) +
                     ' AND PADET.CartonNo between CONVERT(INT,@parm03) AND CONVERT(INT,@parm04)' + CHAR(13) +
                     ' ORDER BY PAH.Pickslipno,CAST(PADET.CartonNo as NVARCHAR(20))'	
		
       
       
        SET @c_ExecArguments = N'@parm01          NVARCHAR(80), ' 
                             + ' @parm02          NVARCHAR(80),'
                             + ' @parm03          NVARCHAR(80),'
                             + ' @parm04          NVARCHAR(80)'
                       
    	 
    	 SET @c_SQL = @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_SQLOrdBy
    	
    	PRINT @c_SQL
    	
    EXEC sp_executesql   @c_SQL  
                       , @c_ExecArguments    
                       , @parm01 
                       , @parm02 
                       , @parm03 
                       , @parm04 
                       
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  

                                  
   END -- procedure   


GO