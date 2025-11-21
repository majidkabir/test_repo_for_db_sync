SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_Shiplabel_GetParm                                   */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2016-11-11 1.0  CSCHONG    Created                                         */                   
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_CTNLABEL_GetParm]                        
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
   SET ANSI_WARNINGS OFF                        
                                
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
      
    --SELECT DISTINCT @c_getUCCno = ISNULL(UccNo,'')  
    --FROM UCC WITH (NOLOCK)  
    --WHERE UccNo = @parm01  
    --AND STATUS='1'  
      
    --SELECT DISTINCT @c_getUdef09 = ISNULL(UccNo,'')  
    --FROM UCC WITH (NOLOCK)  
    --WHERE Userdefined09 = @parm01  
      
    SET @c_ExecArguments = ''  
  
    SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=PH.Pickheaderkey,PARM2='''',PARM3='''',PARM4='''',PARM5='''',' + CHAR(13) +  
                     ' PARM6='''',PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1=''loadkey'',Key2='''',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +  
                     ' FROM ORDERS O (NOLOCK) ' + CHAR(13) +  
                     ' JOIN ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey) ' + CHAR(13) +  
                     ' JOIN PACK P (NOLOCK) ON (P.PackKey = OD.PackKey) ' + CHAR(13) +  
                     ' JOIN PICKHEADER PH (NOLOCK) ON (OD.OrderKey = PH.OrderKey) '+ CHAR(13) +  
                     ' JOIN LOADPLANDETAIL LD (NOLOCK) on (OD.Orderkey = LD.Orderkey AND OD.Loadkey = LD.Loadkey) '+ CHAR(13) +  
                     ' JOIN LOADPLAN L (NOLOCK) ON (L.Loadkey = OD.Loadkey) '  
  
      
      IF ISNULL(@parm01,'')  <> ''  
      BEGIN         
      SET @c_condition1 = ' WHERE PH.Externorderkey = @parm01 '  
      END  
        
      IF ISNULL(@parm02,'')  <> ''  
      BEGIN         
      SET @c_condition1 = ' WHERE PH.Pickheaderkey = @parm02 '  
      END  
        
      SET @c_condition2 = ' AND PH.Orderkey <> '''' ' +  
                           ' AND   (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0  ' +  
                           ' AND   P.CaseCnt > 0  '  
   
        --SET @c_SQLGroup = ' GROUP BY P.OrderKey,Ord.shipperkey '  
        SET @c_SQLOrdBy = ' ORDER BY PH.Pickheaderkey'   
         
         
        SET @c_ExecArguments = N'@parm01          NVARCHAR(80), '   
                             + ' @parm02          NVARCHAR(80)'  
                         
        
      SET @c_SQL = @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_SQLOrdBy  
       
     PRINT @c_SQL  
       
    EXEC sp_executesql   @c_SQL    
                       , @c_ExecArguments      
                       , @parm01   
                       , @parm02   
                         
   EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()    
  
                                    
   END -- procedure     
 

GO