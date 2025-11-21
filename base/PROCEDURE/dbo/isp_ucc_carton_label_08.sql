SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_UCC_Carton_Label_08                            */  
/* Creation Date: 23-Apr-2009                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Rick Liew                                                */  
/*                                                                      */  
/* Purpose:  To print the Ucc Carton Label 08                           */  
/*                                                                      */  
/* Input Parameters:  @c_Storerkey ,PickSlipNo,CartonNo                 */  
/*                                                                      */  
/* Output Parameters:                                                   */
/*                                                                      */  
/* Usage:                                                               */
/*                                                                      */  
/* Called By:  r_dw_ucc_carton_label_08                                 */  
/*                                                                      */  
/* PVCS Version: 1.4                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */
/*	04May2010	 GTGOH	1.1   Change ConsigneeKey from 'M100214' to     */	
/*                            'M103211' for printing of                 */
/*								      ORDERDETAIL.UserDefine01 SOS#170330(GOH01)*/		
/* 30-OCT-2012  YTWan   1.2   SOS#254718:Get Store from Storer.Company  */
/*                            (Wan01)                                   */
/* 28-Jan-2019  TLTING_ext 1.3  enlarge externorderkey field length     */
/* 06-Apr-2023  WLChooi 1.4   WMS-22159 Extend Userdefine01 to 50 (C01) */
/* 06-Apr-2023  WLChooi 1.4   DevOps Combine Script                     */ 
/************************************************************************/  



CREATE   PROC [dbo].[isp_UCC_Carton_Label_08] (
      @cStorerKey        NVARCHAR(15) = '',
      @cPickSlipNo       NVARCHAR(15) = '',
      @cStartCartonNo    int = '',
      @cEndCartonNo      int = ''  
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
DECLARE 
        @c_errmsg      NVARCHAR(255),
        @b_success     int,
        @n_err         int, 
        @b_debug       int   

DECLARE @n_continue        int 
      , @n_StartTCnt       int
      , @c_ExecStatements  NVARCHAR(4000)
      , @c_ExecStatements1 NVARCHAR(4000) 
      , @c_CheckConsignee  NVARCHAR(10)        



DECLARE @t_Result Table (
PickSlipNo     NVARCHAR(10),
LabelNo        NVARCHAR(20),
ORDERKEY       NVARCHAR(10), 
ExternOrderKey NVARCHAR(50),  --tlting_ext
InvoiceNo      NVARCHAR(20),
CartonNo       int,
Qty            int, 
Userdefine04   NVARCHAR(20), 
Consigneekey   NVARCHAR(15), 
C_Company      NVARCHAR(45),
C_Address1     NVARCHAR(45),
C_Address2     NVARCHAR(45),
C_Address3     NVARCHAR(45),
C_Address4     NVARCHAR(45),
C_City         NVARCHAR(45),
CompanyFrom    NVARCHAR(45),
Address1From	NVARCHAR(45), 
Address2From	NVARCHAR(45), 
Address3From 	NVARCHAR(45), 
date           datetime,  
DeliveryDate   datetime,
AlternateSKu   NVARCHAR(20),
sValue         NVARCHAR(10),
Userdefine01   NVARCHAR(50),   --C01
UserDefine02   NVARCHAR(20),
Det_userDefine1 NVARCHAR(18),
EditWho        NVARCHAR(18),
PickerID       NVARCHAR(18))  

SET @c_ExecStatements = ''
SET @c_ExecStatements1 = ''
 

      SELECT @c_CheckConsignee = Orders.Consigneekey FROM Orders WITH (NOLOCK)
      JOIN PACKHEADER PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
      WHERE ORDERS.StorerKey =  @cStorerKey
      AND PACKHEADER.PickSlipNo = @cPickSlipNo 

      SET @c_ExecStatements = N' SELECT PACKHEADER.PickSlipNo, '+ 
		 'PACKDETAIL.LabelNo, '+ 
		 'ORDERS.ORDERKEY, '+ 
		 'ORDERS.ExternOrderKey, '+ 
		 'ORDERS.InvoiceNo,'+ 
		 'PACKDETAIL.CartonNo, '+ 
		 '(SELECT ISNULL(MAX(P2.CartonNo), '''')'+  
		 ' FROM PACKDETAIL P2 (NOLOCK) '+ 
		 ' WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo'+ 
		 ' HAVING SUM(P2.Qty) = (SELECT SUM(QtyAllocated+QtyPicked+ShippedQty) FROM ORDERDETAIL OD2 WITH (NOLOCK)'+ 
		 '								WHERE OD2.OrderKey = PACKHEADER.OrderKey) ) AS CartonMax, '+ 
		 'SUM(PACKDETAIL.Qty) AS Qty, '+ 
		 'ORDERS.Userdefine04, '+ 
		 'ORDERS.Consigneekey,'+  
		 'ORDERS.C_Company,'+  
		 'ORDERS.C_Address1,'+  
		 'ORDERS.C_Address2,'+  
		 'ORDERS.C_Address3,'+  
		 'ORDERS.C_Address4,'+  
		 'ORDERS.C_City,'+ 
		 'PACKHEADER.Route,'+  
       --(Wan01) - START  
		 --'ORDERS.C_Zip,'+ 
       ''''','+  
       --(Wan01) - END 
		 'MAX(IDS.Company) CompanyFrom,'+ 
		 'MAX(IDS.Address1) Address1From,'+ 
		 'MAX(IDS.Address2) Address2From,'+ 
		 'MAX(IDS.Address3) Address3From,'+ 
		 'CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + '' '' + CONVERT(CHAR(8), GetDate(), 108))as date,'+ 
		 'ORDERS.DeliveryDate,'+ 
       'MAX(SKU.AltSKU) AlternateSKu,'+ 
       'ISNULL(STORERCONFIG.SValue, ''0'') sValue,'+ 
		 'ORDERS.Userdefine01,'+ 
		 'ORDERS.BUYERPO,'+ 
		 'ORDERS.UserDefine06,'+ 
		 'ORDERS.UserDefine02,'+
       --(Wan01) - START 
       'ST_COmpany = ISNULL(RTRIM(STORERContact.Company),''''),'  
       --(Wan01) - END 
--GOH01         IF @c_CheckConsignee = 'M100214'	
      IF @c_CheckConsignee = 'M103211'		--GOH01
      BEGIN
         SET @c_ExecStatements = ISNULL(RTRIM(@c_ExecStatements),'') +
       'CASE ORDERS.Consigneekey  '+ 
--GOH01       '  WHEN  ''M100214'' THEN'+ 
       '  WHEN  ''M103211'' THEN'+		--GOH01
       '(select Top 1 ORDERDETAIL.UserDefine01 from ORDERDETAIL ORDERDETAIL (NOLOCK) '+ 
       '  where packheader.OrderKey = ORDERDETAIL.OrderKey'+ 
       '  and packdetail.sku = orderdetail.sku ) '+   
       '  ELSE ''''  '+ 
       'END AS Det_userDefine1,'  
      END 
      ELSE
      BEGIN
         SET @c_ExecStatements = ISNULL(RTRIM(@c_ExecStatements),'') +
         '''''AS Det_userDefine1,'
      END
		SET @c_ExecStatements = ISNULL(RTRIM(@c_ExecStatements),'') + 'PACKHEADER.EditWho,'+ 
		  'PI.PickerID  '+ 
        'FROM ORDERS ORDERS WITH (NOLOCK) '+ 
        'JOIN PACKHEADER PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)'+ 
        'JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  '+ 
        'JOIN SKU SKU WITH (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)'+ 
        'JOIN STORER  WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)'+  
        'JOIN PICKINGINFO PI WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PI.PickSlipNo)'+ 
        'LEFT OUTER JOIN STORER STORERContact WITH (NOLOCK) ON ( STORERContact.Type = ''2'' AND STORERContact.StorerKey = ORDERS.ConsigneeKey) '+  
        'LEFT OUTER JOIN FACILITY WITH (NOLOCK) ON (FACILITY.Facility = ORDERS.Facility) '+ 
        'LEFT OUTER JOIN STORER IDS WITH (NOLOCK) ON (IDS.Storerkey = FACILITY.UserDefine10)'+  
        'LEFT OUTER JOIN STORERCONFIG WITH (NOLOCK) ON (ORDERS.Consigneekey = STORERCONFIG.Storerkey AND STORERCONFIG.Configkey = ''ALTSKUonCTNLBL'')'+ 
        'WHERE ORDERS.StorerKey = N''' + RTRIM(@cStorerkey) +''' '+ 
        'AND PACKHEADER.PickSlipNo = ''' + RTRIM(@cPickSlipNo) +''' '+
        'AND PACKDETAIL.CartonNo BETWEEN CAST(''' + RTRIM(@cStartCartonNo) +'''  as int) AND CAST(''' + RTRIM(@cEndCartonNo) +''' as Int) '+ 
        'GROUP BY PACKHEADER.PickSlipNo, '+ 
			'PACKDETAIL.LabelNo, '+ 
			'ORDERS.ORDERKEY, '+ 
			'ORDERS.ExternOrderKey, '+ 
		 	'ORDERS.InvoiceNo,'+ 
			'PACKDETAIL.CartonNo, '+ 
			'ORDERS.Userdefine04, '+ 
			'ORDERS.Consigneekey, '+ 
			'ORDERS.C_Company, '+ 
			'ORDERS.C_Address1, '+ 
			'ORDERS.C_Address2, '+ 
			'ORDERS.C_Address3, '+ 
			'ORDERS.C_Address4, '+ 
		   'ORDERS.C_City,'+ 		 
			'PACKHEADER.Route, '+ 
         --(Wan01) - START
			--'ORDERS.C_Zip,'+  
         --(Wan01) - END
			'PACKHEADER.OrderKey,'+ 
		 	'ORDERS.DeliveryDate,'+ 
         'STORERCONFIG.SValue,'+ 
		   'ORDERS.Userdefine01,'+ 
			'ORDERS.BUYERPO,'+ 
		  	'ORDERS.UserDefine06,'+ 
		   'ORDERS.UserDefine02,'+
         --(Wan01) - START
         'ISNULL(RTRIM(STORERContact.Company),''''),'  
         --(Wan01) - END
--GOH01      IF @c_CheckConsignee = 'M100214' 
      IF @c_CheckConsignee = 'M103211' 
      BEGIN
         SET @c_ExecStatements = ISNULL(RTRIM(@c_ExecStatements),'') +
	      'PACKDETAIL.Sku,' 
      END 
		  SET @c_ExecStatements = ISNULL(RTRIM(@c_ExecStatements),'') +	
         'PACKHEADER.EditWho,'+ 
		 	'PI.PickerID ;'  

      EXEC (@c_ExecStatements)

      
   --SELECT * FROM #t_Result 

END


GO