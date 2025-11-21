SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PrintDelivery_Summ_01                          */  
/* Creation Date:  10-Nov-2008                                          */  
/* Copyright: IDS                                                       */  
/* Written by:  YTWAN                                                   */  
/*                                                                      */  
/* Purpose:  SOS#122464 Swire ?Report Enhancement                       */  
/*                                                                      */  
/*                                                                      */  
/* Input Parameters:  @a_s_LoadKey  - (LoadKey)                         */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  Report                                               */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: PB - r_dw_delivery_order_01                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 17-JUN-2009  NJOW01    1.1   Add Orders.BuyerPO column               */  
/* 11-July-2017 JyhBin    1.2   IN00387611 Reduce Puma Blocking Issue   */  
/* 28-Jan-2019  TLTING_ext 1.3  enlarge externorderkey field length      */  
/* 25-Mar-2020  CSCHONG   1.4   WMS-12497 revised deliverydate logic(CS01)*/  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_PrintDelivery_Summ_01] (  
       @cMBOLKey       NVARCHAR(10) = ''   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_continue    int,  
           @c_errmsg      NVARCHAR(255),  
           @b_success     int,  
           @n_err         int,   
           @b_debug       int  
  
   DECLARE @n_cnt int  
          , @cConsigneeKey NVARCHAR(15)  
          , @n_grouping    int  
  
      
   DECLARE @t_Result Table (  
         Mbolkey              NVARCHAR(10),  
         EditDate             Datetime,  
         ArrivalDate          datetime,   
         StorerKey            NVARCHAR(15),  
         ConsigneeKey         NVARCHAR(15),  
         C_Company            NVARCHAR(45),  
         C_Address1           NVARCHAR(45),   
         C_Address2           NVARCHAR(45),   
         C_Address3           NVARCHAR(45),   
         C_Address4           NVARCHAR(45),  
         ExternOrderKey       NVARCHAR(50),  --tlting_ext  
         QTY                  int,  
         CartonCnt            int,  
         group_flag           int ,  
         nos                  int,  
         rowid                int IDENTITY(1,1),  
         Carrier_Company    NVARCHAR(45),    
         Contact1           NVARCHAR(30),    
         Phone1             NVARCHAR(18),    
         Fax1                 NVARCHAR(18),    
 Email1               NVARCHAR(60),  
         Loadkey            NVARCHAR(10),  
         BuyerPO         NVARCHAR(20))--NJOW01  
  
   SET @b_debug = 0  
  
   IF @b_debug = 1  
   BEGIN       
      SELECT MBOL.Mbolkey,  
         MBOL.EditDate,  
         --MBOL.ArrivalDate,  
         MBOL.Editdate + ISNULL(cast(CL2.short as int),0) as ArrivalDate,  --CS01  
         ORDERS.Storerkey,    
         ORDERS.ConsigneeKey,     
         ORDERS.C_Company,     
         ORDERS.C_Address1,     
         ORDERS.C_Address2,     
         ORDERS.C_Address3,     
         ORDERS.C_Address4,     
         ORDERS.ExternOrderKey,  
         QTY = SUM (ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyPicked ),     
         CartonCnt = ISNULL(( Select COUNT( Distinct PD.PickSlipNo +''+ convert(NVARCHAR(10),PD.CartonNo) )  
                              FROM PACKDETAIL PD WITH (NOLOCK)    
                              JOIN PackHeader PH WITH (NOLOCK) on ( PH.PickSlipNO  = PD.PickSlipNO )  
                              JOIN ORDERS O WITH (NOLOCK) on ( PH.OrderKey = O.OrderKey  
                                             AND PH.LoadKey = O.LoadKey )  
            WHERE O.Mbolkey  = MBOL.Mbolkey    
            AND  ISNULL(O.ConsigneeKey, '') = ISNULL(ORDERS.ConsigneeKey, '')    
            AND  ISNULL(O.ExternOrderKey, '') = ISNULL(ORDERS.ExternOrderKey, '')), 0) ,  
         0,  
         1,  
         ISNULL(CARRIER.Company, ''),    
         STORER.Contact1,    
         STORER.Phone1,    
         STORER.Fax1,    
         STORER.Email1,  
         ORDERS.BuyerPO  --NJOW01    
       FROM ORDERDETAIL WITH (NOLOCK)     
       JOIN ORDERS WITH (NOLOCK) on ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )     
       JOIN STORER WITH (NOLOCK) on ( STORER.StorerKey = ORDERS.StorerKey )     
       JOIN MBOL WITH (NOLOCK) on (ORDERDETAIL.Mbolkey = MBOL.Mbolkey)  
       LEFT OUTER JOIN STORER CARRIER WITH (NOLOCK) ON ( CARRIER.Storerkey = MBOL.Carrierkey ) -- June01  
       LEFT OUTER JOIN Codelkup CL2 WITH (NOLOCK)      
       ON (CL2.Listname = 'CityLdTime' AND substring(CL2.code,1,4) = 'PUMA' AND CHARINDEX(LTRIM(RTRIM(CL2.description)), ORDERS.c_city) > 0)    
       WHERE ( MBOL.Mbolkey = @cMBOLKey )   
       GROUP BY  MBOL.Mbolkey,  
                 MBOL.EditDate,  
               --MBOL.ArrivalDate,    --CS01  
                 MBOL.Editdate + ISNULL(cast(CL2.short as int),0),  --CS01  
                 ORDERS.ConsigneeKey,     
                 ORDERS.Storerkey,    
                 ORDERS.C_Company,     
                 ORDERS.C_Address1,     
                 ORDERS.C_Address2,     
                 ORDERS.C_Address3,     
                 ORDERS.C_Address4,     
                 ORDERS.ExternOrderKey,  
                 ISNULL(CARRIER.Company, ''),    
                 STORER.Contact1,    
                 STORER.Phone1,    
                 STORER.Fax1,    
                 STORER.Email1,    
                 ORDERS.BuyerPO --NJOW01  
   END  
  
      INSERT INTO  @t_Result  
         (  Mbolkey,     
            EditDate,      
            ArrivalDate,   
            StorerKey,   
            ConsigneeKey,   
            C_Company,   
            C_Address1,   
            C_Address2,   
            C_Address3,   
            C_Address4,  
            ExternOrderKey,    
            QTY,    
            CartonCnt,  
            group_flag ,   
            nos,  
            Carrier_Company,   
            Contact1,   
            Phone1,   
            Fax1,  
            Email1,  
            Loadkey,  
            BuyerPO) --NJOW01   
     SELECT MBOL.Mbolkey,  
            MBOL.EditDate,  
            --MBOL.ArrivalDate,  
            MBOL.Editdate + ISNULL(cast(CL2.short as int),0) as ArrivalDate,  --CS01  
            ORDERS.Storerkey,    
            ORDERS.ConsigneeKey,     
            ORDERS.C_Company,     
            ORDERS.C_Address1,     
            ORDERS.C_Address2,     
            ORDERS.C_Address3,     
            ORDERS.C_Address4,     
            ORDERS.ExternOrderKey,  
            QTY = SUM (ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyPicked ),     
            CartonCnt = ISNULL(( SELECT COUNT( Distinct PD.PickSlipNo +''+ convert(NVARCHAR(10),PD.CartonNo) )  
                                  FROM PACKHEADER PH WITH (NOLOCK)  --IN00387611  
                                  JOIN PACKDETAIL PD WITH (NOLOCK) ON ( PH.PickSlipNO  = PD.PickSlipNO )--IN00387611  
                                  JOIN ORDERS O WITH (NOLOCK) ON ( PH.LoadKey = O.LoadKey and ph.storerkey = o.storerkey) --IN00387611  
                                  WHERE O.Mbolkey  = MBOL.Mbolkey    
                                  AND  ISNULL(O.ConsigneeKey, '') = ISNULL(ORDERS.ConsigneeKey, '')), 0) ,  
            0,  
            1,  
            ISNULL(CARRIER.Company, ''),   
            STORER.Contact1,  
            STORER.Phone1,  
            STORER.Fax1,   
            STORER.Email1,   
            ORDERS.Loadkey,  
            ORDERS.BuyerPO --NJOW01     
       FROM ORDERDETAIL WITH (NOLOCK)     
            JOIN ORDERS WITH (NOLOCK) on ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )     
            JOIN STORER WITH (NOLOCK) on ( STORER.StorerKey = ORDERS.StorerKey )     
            JOIN MBOL WITH (NOLOCK) on (ORDERDETAIL.Mbolkey = MBOL.Mbolkey)  
            LEFT OUTER JOIN STORER CARRIER WITH (NOLOCK) ON ( CARRIER.Storerkey = MBOL.Carrierkey )   
         LEFT OUTER JOIN Codelkup CL2 WITH (NOLOCK)      
             ON (CL2.Listname = 'CityLdTime' AND substring(CL2.code,1,4) = 'PUMA' AND CHARINDEX(LTRIM(RTRIM(CL2.description)), ORDERS.c_city) > 0)   
      WHERE ( MBOL.Mbolkey = @cMBOLKey )   
      GROUP BY MBOL.Mbolkey,  
               MBOL.EditDate,  
              --MBOL.ArrivalDate,  
               MBOL.Editdate + ISNULL(cast(CL2.short as int),0),  --CS01  
               ORDERS.Storerkey,    
               ORDERS.ConsigneeKey,     
               ORDERS.C_Company,     
               ORDERS.C_Address1,     
               ORDERS.C_Address2,     
               ORDERS.C_Address3,     
               ORDERS.C_Address4,     
               ORDERS.ExternOrderKey,  
               ISNULL(CARRIER.Company, ''),  
               STORER.Contact1,  
               STORER.Phone1,  
               STORER.Fax1,   
               STORER.Email1,  
               ORDERS.Loadkey,  
               ORDERS.BuyerPO --NJOW01  
     
        
      DECLARE C_Grouping CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Distinct ConsigneeKey  
      FROM   @t_Result     
      ORDER BY ConsigneeKey -- June01   
        
      OPEN C_Grouping  
           
      FETCH NEXT FROM C_Grouping INTO @cConsigneeKey   
           
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         Set @n_grouping = 1  
  
         While 1 = 1  
         BEGIN              
            IF not exists (SELECT 1  
                           FROM  @t_Result   
                           WHERE ConsigneeKey = @cConsigneeKey  
                           AND   MBOLKey = @cMBOLKey  
                           AND   group_flag = 0 )  
            BEGIN  
               break  
            END  
  
            Set RowCount 10  
  
            Update @t_Result  
            SET   group_flag = @n_grouping  
            WHERE ConsigneeKey = @cConsigneeKey  
            AND   MBOLKey = @cMBOLKey  
            AND   group_flag = 0   
  
            SET @n_grouping = @n_grouping + 1  
            SET RowCount 0  
  
     
         END -- end while 1=1     
         FETCH NEXT FROM C_Grouping INTO @cConsigneeKey  
      END   
        
      CLOSE C_Grouping  
      DEALLOCATE C_Grouping      
  
     
Quit:  
   SELECT * FROM @t_Result   
   ORDER BY RowID   
END  

GO