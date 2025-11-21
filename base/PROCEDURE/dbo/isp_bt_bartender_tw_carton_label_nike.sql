SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_BT_Bartender_TW_Carton_Label_NIKE              */  
/* Creation Date: 09-JUL-2017                                           */  
/* Copyright: IDS                                                       */  
/* Written by:CSCHONG                                                   */  
/*                                                                      */  
/* Purpose: WMS-2292- TW Nike Create Bartender for Carton Label         */  
/*                                                                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_BT_Bartender_TW_Carton_Label_NIKE] (  
   @c_Sparm1            NVARCHAR(250),                      
   @c_Sparm2            NVARCHAR(250),                      
   @c_Sparm3            NVARCHAR(250),                      
   @c_Sparm4            NVARCHAR(250),                      
   @c_Sparm5            NVARCHAR(250),                      
   @c_Sparm6            NVARCHAR(250),                      
   @c_Sparm7            NVARCHAR(250),                      
   @c_Sparm8            NVARCHAR(250),                      
   @c_Sparm9            NVARCHAR(250),                      
   @c_Sparm10           NVARCHAR(250),                
   @b_debug             INT = 0    
)  
AS  
BEGIN  
   SET NOCOUNT ON   -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF          
  
   DECLARE @n_continue    int,  
           @c_errmsg      NVARCHAR(255),  
           @b_success     int,  
           @n_err         INT,  
           @cLoadKey      NVARCHAR(10),   
           @cPickSlipNo    NVARCHAR(10),   
           @nNoOfCartons   int   
     
     DECLARE @d_Trace_StartTime   DATETIME,           
           @d_Trace_EndTime    DATETIME,          
           @c_Trace_ModuleName NVARCHAR(20),           
           @d_Trace_Step1      DATETIME,           
           @c_Trace_Step1      NVARCHAR(20),          
           @c_UserName         NVARCHAR(20)    
     
     
    DECLARE @cExternOrderKey  NVARCHAR(20),  
              @cOrderKey        NVARCHAR(10),  
              @cCompany         NVARCHAR(60),  
              @nCartonNo        int,   
              @nTotalCarton     int,  
              @cBarCode         NVARCHAR(20),  
              @cStop            NVARCHAR(20),  
              @cDeliveryPlace   NVARCHAR(45),  
              @cAddress         NVARCHAR(124),   
              @cPhone           NVARCHAR(20),   
              @cInvoiceNo       NVARCHAR(20),  
              @cSeqNo           NVARCHAR(30),  
              @PickSlipNo       NVARCHAR(10),  
              @cDeliveryDate    NVARCHAR(10)  
                
       SET @nNoOfCartons = 1         
                
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
  
   CREATE Table #temp_Ctn01Result  (  
         CartonNo             NVARCHAR(5),  
         PickSlipNo           NVARCHAR(10),  
         rowid                int IDENTITY(1,1)   )  
  
   SET NOCOUNT ON  
   --DECLARE Cur1 Scroll Cursor FOR  
/* DISCRETE: PH.Orderkey <> '' Then (O.OrderKey = PH.OrderKey)  */  
DECLARE Cur1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
   SELECT O.ExternOrderkey, OD.OrderKey,   
          ISNULL(O.C_Company, ''),          
          CASE cast(PH.consigneekey as int)   
            WHEN 0     THEN 'd d'  
           ELSE 'd' +RIGHT ( REPLICATE ('0', 10)+ dbo.fnc_LTRIM( dbo.fnc_RTRIM( STR( CAST(PH.consigneekey as int)))),10) + 'd'  
          END,                                          
          CEILING(CONVERT(DECIMAL(8,2), SUM((OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) / P.CaseCnt))),  
          O.route,                     
          ISNULL(O.DeliveryPlace, ''),   
          ISNULL(dbo.fnc_RTRIM(O.C_Address3), '')+' '+ISNULL(dbo.fnc_RTRIM(O.C_Address2), ''),      
          ISNULL(O.C_City, ''),                                    
          '',                                                      
          LD.LoadLineNumber,                                       
          PH.PickHeaderKey,  
          CONVERT(char(10), L.lpuserdefdate01, 111)   
   FROM ORDERS O (NOLOCK)  
   JOIN ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)  
   JOIN PACK P (NOLOCK) ON (P.PackKey = OD.PackKey)   
   JOIN PICKHEADER PH (NOLOCK) ON (OD.OrderKey = PH.OrderKey)   
   JOIN LOADPLANDETAIL LD (NOLOCK) on (OD.Orderkey = LD.Orderkey AND OD.Loadkey = LD.Loadkey)   
   JOIN LOADPLAN L (NOLOCK) ON (L.Loadkey = OD.Loadkey)   
   WHERE PH.Pickheaderkey = @c_Sparm1  
   AND PH.Orderkey <> ''  
   AND   (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0   
   AND   P.CaseCnt > 0   
   GROUP BY O.ExternOrderkey, OD.OrderKey, ISNULL(O.C_Company, ''),   
          PH.consigneekey, O.route,   
          ISNULL(O.DeliveryPlace, ''),   
          ISNULL(dbo.fnc_RTRIM(O.C_Address3), '') + ' ' + ISNULL(dbo.fnc_RTRIM(O.C_Address2), ''),  
          ISNULL(O.C_City, ''),   
          LD.LoadLineNumber,   
          PH.PickHeaderKey,  
          CONVERT(char(10), L.lpuserdefdate01, 111)   
 UNION     
   SELECT ' ' As ExternOrderKey,' ' As OrderKey,  
          ISNULL(O.C_Company, ''),        
          CASE cast(PH.consigneekey as int)   
            WHEN 0     THEN 'd d'  
           ELSE 'd' +RIGHT ( REPLICATE ('0', 10)+ dbo.fnc_LTRIM( dbo.fnc_RTRIM( STR( CAST(PH.consigneekey as int)))),10) + 'd'  
          END,                                           
          CEILING(CONVERT(DECIMAL(8,2), SUM((OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) / P.CaseCnt))),  
          O.route,                   
          ISNULL(O.DeliveryPlace, ''),   
          ISNULL(dbo.fnc_RTRIM(O.C_Address3), '') + ' ' + ISNULL(dbo.fnc_RTRIM(O.C_Address2), ''),    
          ISNULL(O.C_City, ''),          
          '',                
          '1',  
          PH.PickHeaderKey,  
          CONVERT(char(10), L.lpuserdefdate01, 111)   
   FROM ORDERS O (NOLOCK)  
   JOIN ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)  
   JOIN PACK P (NOLOCK) ON (P.PackKey = OD.PackKey)   
   JOIN PICKHEADER PH (NOLOCK) ON (OD.Loadkey = PH.ExternOrderkey)   
   JOIN LOADPLAN L (NOLOCK) ON (L.Loadkey = OD.Loadkey)   
   WHERE PH.Pickheaderkey = @c_Sparm1  
   AND PH.Orderkey = ''  
   AND   (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0   
   AND   P.CaseCnt > 0   
   GROUP BY ISNULL(O.C_Company, ''),      
          PH.consigneekey, O.route,   
          ISNULL(O.DeliveryPlace, ''),   
          ISNULL(dbo.fnc_RTRIM(O.C_Address3), '') + ' ' + ISNULL(dbo.fnc_RTRIM(O.C_Address2), ''),  
          ISNULL(O.C_City, ''),                 
          PH.PickHeaderKey,    
          CONVERT(char(10), L.lpuserdefdate01, 111)  
   ORDER BY PH.PickHeaderKey   
  
      OPEN Cur1  
        
    FETCH NEXT FROM Cur1 INTO @cExternOrderKey, @cOrderKey, @cCompany, @cBarCode,  @nTotalCarton, @cStop,   
                              @cDeliveryPlace, @cAddress, @cPhone, @cInvoiceNo, @cSeqNo, @PickSlipNo, @cDeliveryDate   
  WHILE @@Fetch_Status <> -1  
  BEGIN  
            IF @nTotalCarton = 0   
            SELECT @nTotalCarton = 1  
            SELECT @nCartonNo = 1   
        
      IF @b_debug = 1  
      BEGIN  
       SELECT @nTotalCarton '@nTotalCarton',@nCartonNo '@nCartonNo'  
      END  
        
   While @nCartonNo <= @nTotalCarton  
   BEGIN  
    INSERT INTO #temp_Ctn01Result (CartonNo, PickSlipNo)  
    VALUES ( CAST(@nCartonNo AS NVARCHAR(5)), @PickSlipNo)    
    SELECT @nCartonNo = @nCartonNo + 1  
   END  
      FETCH NEXT FROM Cur1 INTO @cExternOrderKey, @cOrderKey, @cCompany, @cBarCode,  @nTotalCarton, @cStop,   
                 @cDeliveryPlace, @cAddress, @cPhone, @cInvoiceNo, @cSeqNo, @PickSlipNo, @cDeliveryDate   
  END   
   
   CLOSE Cur1  
   DEALLOCATE Cur1  
     
--Quit:  
  
      IF @b_debug = 1  
      BEGIN  
       SELECT  PickSlipNo, CartonNo FROM #temp_Ctn01Result AS tcr   
      END  
  
      INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                            ,Col55,Col56,Col57,Col58,Col59,Col60)       
     SELECT PickSlipNo, CartonNo ,'','','','',           
            '','','','','','','','','','','','','','',          
            '','','','','','','','','','','','','','','','','','','','','','','','','','','','','',''          
            ,'','','','','','','','','',''  
    FROM #temp_Ctn01Result   
    ORDER BY rowid--PickSlipNo,CartonNo   
      
    SELECT * from #result WITH (NOLOCK)  
   --ORDER BY Col02  
           
      
   EXIT_SP:            
          
   SET @d_Trace_EndTime = GETDATE()          
   SET @c_UserName = SUSER_SNAME()          
             
   EXEC isp_InsertTraceInfo           
      @c_TraceCode = 'BARTENDER',          
      @c_TraceName = 'isp_BT_Bartender_TW_Carton_Label_NIKE',          
      @c_starttime = @d_Trace_StartTime,          
      @c_endtime = @d_Trace_EndTime,          
      @c_step1 = @c_UserName,          
      @c_step2 = '',          
      @c_step3 = '',          
      @c_step4 = '',          
      @c_step5 = '',          
      @c_col1 = @c_Sparm1,           
      @c_col2 = @c_Sparm2,          
      @c_col3 = @c_Sparm3,          
      @c_col4 = @c_Sparm4,          
      @c_col5 = @c_Sparm5,          
      @b_Success = 1,          
      @n_Err = 0,          
      @c_ErrMsg = ''      
END  


GO