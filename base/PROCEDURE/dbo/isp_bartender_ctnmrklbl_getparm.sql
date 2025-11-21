SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_CTNMRKLBL_GetParm                                   */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date        Author   Rev   Purposes                                        */   
/* 11-OCT-2021 CSCHONG  1.0   Devops scripts combine                          */                
/* 11-OCT-2021 CSCHONG  1.1   Created(WMS-17994)                              */                   
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_CTNMRKLBL_GetParm]                        
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
      @c_Orderkey        NVARCHAR(10),                      
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
      @c_ExecArguments   NVARCHAR(4000),
      @n_startcartonNo   INT,
      @n_endCartonno     INT,
      @c_PrnByOrder      NVARCHAR(1)  
        
      
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
    SET @c_Orderkey = ''  
    SET @c_getUdef09 = ''    
    SET @c_SQLJOIN = ''          
    SET @c_condition1 = ''  
    SET @c_condition2= ''  
    SET @c_SQLOrdBy = ''  
    SET @c_SQLGroup = ''  
    SET @n_startcartonNo = 1
    SET @n_endCartonno = 1
    SET @c_PrnByOrder = 'N'

    IF EXISTS (SELECT 1 FROM dbo.PackHeader PH WITH (NOLOCK) WHERE PH.PickSlipNo = @parm01)
    BEGIN
         SELECT @c_Orderkey = PH.Orderkey
         FROM dbo.PackHeader PH WITH (NOLOCK)
         WHERE PH.PickSlipNo = @parm01

         SET @n_startcartonNo = CAST(@parm02 AS INT)
         SET @n_endCartonno = CAST(@parm03 AS INT)
       
    END
    ELSE IF EXISTS (SELECT 1 FROM dbo.orders OH WITH (NOLOCK) WHERE OH.Orderkey = @parm01)
    BEGIN
      SET @c_Orderkey = @parm01
      SET @c_PrnByOrder = 'Y'
    END

    SET @c_ExecArguments = ''  
  
    SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=PH.Pickslipno,PARM2=PD.Cartonno,PARM3=O.Storerkey,PARM4='''',PARM5='''',' + CHAR(13) +  
                     ' PARM6='''',PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1='''',Key2='''',Key3='''',Key4='''',Key5=O.Userdefine01 ' + CHAR(13) +  
                     ' FROM  PackHeader PH WITH (NOLOCK) ' + CHAR(13) +  
                     ' JOIN PackDetail PD WITH (NOLOCK)  ON (PH.PickSlipNo = PD.PickSlipNo) ' + CHAR(13) + 
                     ' JOIN ORDERS O (NOLOCK) ON (PH.OrderKey = O.OrderKey) ' + CHAR(13) 
  
      
      IF @c_PrnByOrder = 'N'
      BEGIN         
      SET @c_condition1 = ' WHERE PH.Pickslipno = @parm01 '   + CHAR(13) + 
                          '  AND PD.CartonNo >= CONVERT(INT, @Parm02)  AND PD.CartonNo <= CONVERT(INT, @Parm03) '
      END  
        
      IF @c_PrnByOrder = 'Y' 
      BEGIN         
      SET @c_condition1 = ' WHERE PH.Orderkey = @parm01 '  
      END  
        
      --SET @c_condition2 = ' AND PH.Orderkey <> '''' ' +  
      --                     ' AND   (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0  ' +  
      --                     ' AND   P.CaseCnt > 0  '  
   
        --SET @c_SQLGroup = ' GROUP BY P.OrderKey,Ord.shipperkey '  
        SET @c_SQLOrdBy = ' ORDER BY PH.Pickslipno,PD.Cartonno,O.Storerkey'   
         
         
        SET @c_ExecArguments = N'@parm01          NVARCHAR(80), '   
                             + ' @parm02          NVARCHAR(80),'
                             + ' @parm03          NVARCHAR(80)'  
                           
                         
        
      SET @c_SQL = @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) +  @c_SQLOrdBy  
      
       
    EXEC sp_executesql   @c_SQL    
                       , @c_ExecArguments      
                       , @parm01   
                       , @parm02   
                       , @parm03
                         
   EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()    
  
                                    
   END -- procedure     
 

GO