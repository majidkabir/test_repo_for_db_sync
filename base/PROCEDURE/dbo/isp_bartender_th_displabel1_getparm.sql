SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_TH_DISPLABEL1_GetParm                               */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2021-02-25 1.0  CSCHONG    Created (WMS-16406)                             */                 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_TH_DISPLABEL1_GetParm]                      
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
           @n_copy             INT,
           @n_Maxcopy          INT  
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''   
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    
    SET @n_copy = 0
    
    SET @n_copy = CAST (@Parm02 AS INT)

    SELECT @n_Maxcopy  =SUM(PD.qty)
    FROM PICKDETAIL PD (NOLOCK)
    WHERE PD.orderkey = @Parm01

    IF @n_copy > @n_Maxcopy
    BEGIN
     GOTO EXIT_SP

    END        
          
    
    SET @c_ExecArguments = ''

    SET @c_SQLJOIN = ' SELECT PARM1=@Parm01,PARM2=@n_copy,PARM3='''',PARM4='''',PARM5= '''',' + CHAR(13) +
                     ' PARM6= '''',PARM7= '''',PARM8='''',PARM9='''',PARM10='''',Key1=''orderkey'',Key2='''',Key3='''',Key4='''',Key5='''' ' 

        SET @c_ExecArguments = N'@parm01          NVARCHAR(80),'
                             + ' @parm02          NVARCHAR(80),' 
                             + ' @parm03          NVARCHAR(80),'
                             + ' @n_copy          INT'
                         	 
    SET @c_SQL = @c_SQLJOIN + CHAR(13) 

    	
    EXEC sp_executesql   @c_SQL  
                       , @c_ExecArguments  
                       , @parm01  
                       , @parm02 
                       , @parm03 
                       , @n_copy
                       
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  

                                  
   END -- procedure   



GO