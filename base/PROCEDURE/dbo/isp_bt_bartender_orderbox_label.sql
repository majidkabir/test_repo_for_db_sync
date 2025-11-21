SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

   
/******************************************************************************/         
/* Copyright: IDS                                                             */         
/* Purpose: BarTender Filter by ShipperKey                                    */         
/*                                                                            */         
/* Modifications log:                                                         */         
/*                                                                            */         
/* Date       Rev  Author     Purposes                                        */         
/* 2013-06-21 1.0  CSCHONG    Created                                         */        
/******************************************************************************/        
          
CREATE PROC [dbo].[isp_BT_Bartender_OrderBox_Label]               
(  @c_Sparm1            NVARCHAR(250),      
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
   SET NOCOUNT ON         
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF         
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS OFF              
                      
   DECLARE          
      @c_OrderKey        NVARCHAR(10),            
      @c_ExternOrderKey  NVARCHAR(10),      
      @c_Deliverydate    DATETIME,      
      @c_ConsigneeKey    NVARCHAR(15),      
      @c_Company         NVARCHAR(45),      
      @C_Address1        NVARCHAR(45),      
      @C_Address2        NVARCHAR(45),      
      @C_Address3        NVARCHAR(45),      
      @C_Address4        NVARCHAR(45),      
      @C_BuyerPO         NVARCHAR(20),      
      @C_notes2          NVARCHAR(4000),      
      @c_OrderLineNo     NVARCHAR(5),      
      @c_SKU             NVARCHAR(20),      
      @n_Qty             INT,      
      @c_PackKey         NVARCHAR(10),      
      @c_UOM             NVARCHAR(10),      
      @C_PHeaderKey      NVARCHAR(18),      
      @C_SODestination   NVARCHAR(30),    
      @n_RowNo           INT,    
      @n_SumPickDETQTY   INT,    
      @n_SumUnitPrice    INT,  
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000)
       
    -- SET RowNo = 0     
    SET @c_SQL = ''
    SET @n_SumPickDETQTY = 0    
    SET @n_SumUnitPrice = 0    
      
    CREATE TABLE [#Result] (     
      [ID]    [INT] IDENTITY(1,1) NOT NULL,                    
      [Col1]  [NVARCHAR] (80) NULL,      
      [Col2]  [NVARCHAR] (80) NULL,      
      [Col3]  [NVARCHAR] (80) NULL,      
      [Col4]  [NVARCHAR] (80) NULL,      
      [Col5]  [NVARCHAR] (80) NULL,      
      [Col6]  [NVARCHAR] (80) NULL,      
      [Col7]  [NVARCHAR] (80) NULL,      
      [Col8]  [NVARCHAR] (80) NULL,      
      [Col9]  [NVARCHAR] (80) NULL,      
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


SET @c_SQLJOIN = +' SELECT  ISNULL(STORER.COMPANY, ''''),ISNULL(STORER.ADDRESS1, ''''),ISNULL(STORER.ADDRESS2, ''''),ISNULL(STORER.ZIP, ''''),'  
             + CHAR(13) +   
             +'ISNULL(STORER.CITY, ''''),ISNULL(STORER.COUNTRY, ''''),ISNULL(ORD.CONSIGNEEKEY, '''') ,ISNULL(ORD.M_ADDRESS3, '''') , '  --8
             + CHAR(13) +  
             +'ISNULL(ORD.M_ADDRESS4, '''') ,ISNULL(ORD.M_COUNTRY, '''') ,ISNULL(ORD.M_COMPANY, '''') ,ISNULL(ORD.C_ADDRESS1, ''''),'+ CHAR(13) +  
             +'ISNULL(ORD.C_ADDRESS2, '''') ,ISNULL(ORD.C_ADDRESS3, ''''),ISNULL(ORD.C_ADDRESS4, '''') ,ISNULL(ORD.C_ZIP, '''') ,'  
             + CHAR(13) +  
             +'ISNULL(ORD.C_CITY, '''') ,ISNULL(ORD.C_STATE, '''') ,ISNULL(ORD.COUNTRYDESTINATION, ''''),ISNULL(ORD.USERDEFINE03, ''''),'   
             +'ISNULL(ORD.USERDEFINE05, ''''),ISNULL(ORD.ORDERDATE, '''') ,ISNULL(ORD.EXTERNORDERKEY, ''''),ISNULL(PACKDETAIL.CARTONNO, ''''), '  --50
             +'ISNULL(PACKDETAIL.UPC, ''''),CAST(CAST( PACKINFO.WEIGHT/1000 AS REAL) AS DECIMAL( 10, 2)), '
             +'CASE WHEN M_Address3 = '''' AND M_Address4 = '''' THEN '''' '
             +' WHEN M_Address3 <> '''' AND M_Address4 = '''' THEN M_Address3  '
             +' WHEN M_Address3 = '''' AND M_Address4 <> '''' THEN M_Address4 '
             +' WHEN M_Address3 <> '''' AND M_Address4 <> '''' THEN M_Address3 + M_Address4 ELSE '''' END AS ADDRESS1,'
             +' ISNULL(RTRIM(ORD.CONSIGNEEKEY), '''') + ISNULL(LTRIM(ORD.M_COMPANY), '''') ,'
             +' ''Order num.'' + USERDEFINE05, '
             +' '''','''','''','''','''','''','''','''','''','''','''', '
             +' '''','''','''','''','''','''','''','''','''','''', '
             +' '''','''','''','''','''','''','''','''','''','''' '
             + CHAR(13) +    
             + ' FROM ORDERS ORD WITH (NOLOCK) INNER JOIN PACKHEADER WITH (NOLOCK) '
             + ' ON ORD.ORDERKEY = PACKHEADER.ORDERKEY '
             + ' INNER JOIN PACKDETAIL WITH (NOLOCK) ON PACKHEADER.PICKSLIPNO = PACKDETAIL.PICKSLIPNO '
             + ' INNER JOIN PACKINFO WITH (NOLOCK) ON (PACKDETAIL.PICKSLIPNO = PACKINFO.PICKSLIPNO AND PACKDETAIL.CARTONNO = PACKINFO.CARTONNO)'
             + ' INNER JOIN STORER WITH (NOLOCK) ON STORER.STORERKEY = ''LFZABSDC'''
             + ' WHERE ( ORD.STORERKEY  =''' + @c_Sparm1+ ''') '
             + ' AND  ( ORD.ORDERKEY = ''' + @c_Sparm2+ ''') '
     

      IF @b_debug=1    
      BEGIN    
      PRINT @c_SQLJOIN      
      END            
        
      
  SET @c_SQL='INSERT INTO #Result (Col1,Col2,Col3,Col4,Col5, Col6,Col7,Col8,Col9'  + CHAR(13) +   
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +   
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +   
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +   
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +   
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '  
            -- + CHAR(13) +      
             /*+' SELECT ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8
             + CHAR(13) +   
             +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),ORD.Notes,ORD.Notes2,'''',STO.State,'  --8
             + CHAR(13) +  
             +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +  
             +'ORD.c_Address2,ORD.C_Address3,ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'  
             +'ORD.C_Phone2,ORD.M_Company,ORD.Userdefine01,ORD.Userdefine02,ORD.Userdefine03,ORD.Userdefine04,ORD.Userdefine05,ORD.PmtTerm,'    
             + CHAR(13) +  
             +'ORD.InvoiceAmount,'''','''','   
             +'ORD.ShipperKey,STO.B_Company,(STO.B_Address1+STO.B_Address2+STO.B_Address3),STO.B_Contact1,STO.B_Phone1,'''','''', '  --50
             +' '''','''','''','''','''','''','''','''','''','''' '   
             + CHAR(13) +    
             +'FROM ORDERS ORD (NOLOCK) INNER JOIN #TempOrders Temp (NOLOCK) ON Temp.OrderKey  '  
             +'STORER STO (NOLOCK) ON STO.STORERKEY = ORD.STORERKEY '  
            -- +'INNER JOIN SKUXLOC SXLOC ON SXLOC.storerkey = ORD.storer AND SXLOC.SKU =  '  
             + CHAR(13) +    
           --  +'WHERE ORD.LoadKey =''' + @c_Sparm1+ ''' '--and ORD.OrderKey=''' + @c_Sparm2+ ''' and ORD.ShipperKey= ''' + @c_Sparm3 +''' '  
  */
      SET @c_SQL = @c_SQL + @c_SQLJOIN

      IF @b_debug=1    
      BEGIN    
      PRINT @c_SQL      
      END            

--PRINT LEN(@c_SQL)  
--PRINT @c_SQL  
/*  
IF @c_Sparm4='1'    
BEGIN  
SET @c_SQLJOIN = ' INNER JOIN ORDERDETAIL ORDDET (NOLOCK) ON ORDDET.ORDERKEY = ORD.ORDERKEY '
                 + ' INNER JOIN PICKDETAIL PD (NOLOCK) ON '
SET @c_SQL = @c_SQL + ' And ORD.OpenQTY= 1 '  
END  
ELSE  
BEGIN   
SET @c_SQL = @c_SQL + ' AND ORD.OpenQTY >1 '  
END  
 */ 
EXEC sp_executesql @c_SQL  
  
--PRINT @c_SQL  

SELECT * FROM #Result WITH (nolock)             
      
EXIT_SP:       
                            
END -- procedure     


GO