SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/************************************************************************/  
/* Stored Procedure: isp_PrintDelivery_Summ_Swire                       */  
/* Creation Date: 5/11/2007                                             */  
/* Copyright: IDS                                                       */  
/* Written by: TLTing                                                   */  
/*                                                                      */  
/* Purpose: To print delivery summary for swire.                        */  
/*                                                                      */  
/* Called By: PB - MBOL                                                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 21-Nov-2007  June      SOS90011 - Add Carrier Company, Contact1      */  
/*                                   & Phone1 (June01)                  */  
/* 02-May-2008  Liew      SOS105609 - Add Email1 and Fax1               */  
/* 28-Mac-2011  AQSKC     SOS209707 - change Arrival Date & Add Remark  */  
/*                        (Kc01)                                        */  
/* 29-DEC-2011  YTWan     SOS#233294- Calc Arrival Date by facility.    */  
/*                        (Wan01)                                       */   
/* 02-JUL-2012  NJOW01    248644-get carton qty from mboldetail         */  
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_PrintDelivery_Summ_Swire] (  
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
          , @cConsigneeKey   NVARCHAR(15)  
          , @n_grouping    int  
  
      
   DECLARE @t_Result Table (  
         Mbolkey              NVARCHAR(10),  
--         EditDate             Datetime,  
--         ArrivalDate          datetime,   
         EditDate             NVARCHAR(8),    --(Kc01)  
         ArrivalDate          NVARCHAR(8),    --(KC01)  
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
         Carrier_Company      NVARCHAR(45), -- June01   
         Contact1             NVARCHAR(30), -- June01  
         Phone1               NVARCHAR(18), -- June01  
         Fax1                 NVARCHAR(18), -- SOS105609  
         Email1               NVARCHAR(60), -- SOS105609  
         Remark               NVARCHAR(4000))      --(Kc01)  
  
    SET @b_debug = 0  
  
   IF @b_debug = 1  
   BEGIN       
      SELECT MBOL.Mbolkey,  
         CONVERT(NVARCHAR(8),MBOL.EditDate, 112) AS editdate,                        --(Kc01)  
         CONVERT(NVARCHAR(8),DATEADD(DAY, CONVERT(INT, ISNULL(CL.SHORT,0)), MBOL.EditDate), 112) as arrivaldate,          --(KC01)  
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
         STORER.Contact1, -- June01  
         STORER.Phone1, -- June01  
         STORER.Fax1, -- SOS105609  
         STORER.Email1, -- SOS105609  
         CONVERT(NVARCHAR(4000), STORER.Notes1) As Remark       --(Kc01)  
       FROM ORDERDETAIL WITH (NOLOCK)     
            JOIN ORDERS WITH (NOLOCK) on ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )     
            JOIN STORER WITH (NOLOCK) on ( STORER.StorerKey = ORDERS.StorerKey )     
            JOIN MBOL WITH (NOLOCK) on (ORDERDETAIL.Mbolkey = MBOL.Mbolkey)  
            JOIN FACILITY WITH (NOLOCK) ON (FACILITY.Facility = ORDERS.Facility)                   --(Wan01)  
            LEFT OUTER JOIN STORER CARRIER WITH (NOLOCK)   
               ON ( CARRIER.Storerkey = CASE ISNULL(MBOL.Carrierkey,'') WHEN '' THEN STORER.SUSR1 ELSE MBOL.Carrierkey END) -- (Kc01)   
            LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK)                                               --(Kc01)  
               ON (CL.Listname = 'CityLdTime' AND CONVERT(VARCHAR,CL.Notes) = ORDERS.Storerkey      --(Kc01)  
               AND ISNULL(RTRIM(CL.Description),'') = ISNULL(RTRIM(ORDERS.C_City),'')               --(Kc01)  
               AND ISNULL(RTRIM(CL.Long),'') = ISNULL(RTRIM(FACILITY.UserDefine03),''))            --(Wan01)                
        WHERE ( MBOL.Mbolkey = @cMBOLKey )   
        GROUP BY  MBOL.Mbolkey,  
               CONVERT(NVARCHAR(8),MBOL.EditDate, 112) ,                        --(Kc01)  
               CONVERT(NVARCHAR(8),DATEADD(DAY, CONVERT(INT, ISNULL(CL.SHORT,0)), MBOL.EditDate), 112),   --(Kc01)  
               ORDERS.ConsigneeKey,     
               ORDERS.Storerkey,    
               ORDERS.C_Company,     
               ORDERS.C_Address1,     
               ORDERS.C_Address2,     
               ORDERS.C_Address3,     
               ORDERS.C_Address4,     
               ORDERS.ExternOrderKey,  
               ISNULL(CARRIER.Company, ''),  
               STORER.Contact1, -- June01  
               STORER.Phone1, -- June01  
               STORER.Fax1, -- SOS105609  
               STORER.Email1, -- SOS105609  
               CONVERT(NVARCHAR(4000), STORER.Notes1)        --(Kc01)  
   END  
  
      INSERT INTO  @t_Result  
      ( Mbolkey,   EditDate,    ArrivalDate,   
         StorerKey, ConsigneeKey, C_Company, C_Address1,   
         C_Address2, C_Address3, C_Address4,  
         ExternOrderKey,  QTY,  CartonCnt,  
         group_flag , nos,  
         Carrier_Company, Contact1, Phone1, -- June01   
         Fax1,Email1, -- SOS105609  
         Remark )     --(KC01)  
     SELECT MBOL.Mbolkey,  
         CONVERT(NVARCHAR(8),MBOL.EditDate, 112),                                                       --(Kc01)  
         CONVERT(NVARCHAR(8),DATEADD(DAY, CONVERT(INT, ISNULL(CL.SHORT,0)), MBOL.EditDate), 112),       --(KC01)  
         ORDERS.Storerkey,    
         ORDERS.ConsigneeKey,     
         ORDERS.C_Company,     
         ORDERS.C_Address1,     
         ORDERS.C_Address2,     
         ORDERS.C_Address3,     
         ORDERS.C_Address4,     
         ORDERS.ExternOrderKey,  
         QTY = SUM (ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyPicked ),     
         --CartonCnt = ISNULL(( Select COUNT( Distinct PD.PickSlipNo +''+ convert(char(10),PD.CartonNo) )  
         --   FROM PACKDETAIL PD WITH (NOLOCK)    
         --         JOIN PackHeader PH WITH (NOLOCK) on ( PH.PickSlipNO  = PD.PickSlipNO )  
         --         JOIN ORDERS O WITH (NOLOCK) on ( PH.OrderKey = O.OrderKey  
         --                                    AND PH.LoadKey = O.LoadKey )  
         --   WHERE O.Mbolkey  = MBOL.Mbolkey    
         --   AND  ISNULL(O.ConsigneeKey, '') = ISNULL(ORDERS.ConsigneeKey, '')    
         --   AND  ISNULL(O.ExternOrderKey, '') = ISNULL(ORDERS.ExternOrderKey, '')), 0) ,  
         (SELECT SUM(MD.TotalCartons) FROM MBOLDETAIL MD (NOLOCK)  
          JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey   
          WHERE MD.Mbolkey = MBOL.Mbolkey   
          AND ISNULL(O.Consigneekey,'') = ISNULL(ORDERS.Consigneekey,'')  
          AND ISNULL(O.ExternOrderKey, '') = ISNULL(ORDERS.ExternOrderKey,'')) AS CartonCnt, --NJOW01  
         0,  
         1,  
         ISNULL(CARRIER.Company, ''),  
         STORER.Contact1, -- June01  
         STORER.Phone1, -- June01  
         STORER.Fax1, -- SOS105609  
         STORER.Email1, -- SOS105609  
         CONVERT(NVARCHAR(4000), STORER.Notes1) As Remark       --(Kc01)  
       FROM ORDERDETAIL WITH (NOLOCK)     
            JOIN ORDERS WITH (NOLOCK) on ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )     
            JOIN STORER WITH (NOLOCK) on ( STORER.StorerKey = ORDERS.StorerKey )     
            JOIN MBOL WITH (NOLOCK) on (ORDERDETAIL.Mbolkey = MBOL.Mbolkey)  
            JOIN FACILITY WITH (NOLOCK) ON (FACILITY.Facility = ORDERS.Facility)                   --(Wan01)  
            LEFT OUTER JOIN STORER CARRIER WITH (NOLOCK)   
               ON ( CARRIER.Storerkey = CASE ISNULL(MBOL.Carrierkey,'') WHEN '' THEN STORER.SUSR1 ELSE MBOL.Carrierkey END) -- (Kc01)   
            LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK)                                               --(Kc01)  
               ON (CL.Listname = 'CityLdTime' AND CONVERT(VARCHAR,CL.Notes) = ORDERS.Storerkey      --(Kc01)  
               AND ISNULL(RTRIM(CL.Description),'') = ISNULL(RTRIM(ORDERS.C_City),'')               --(Kc01)  
               AND ISNULL(RTRIM(CL.Long),'') = ISNULL(RTRIM(FACILITY.UserDefine03),''))            --(Wan01)     
        WHERE ( MBOL.Mbolkey = @cMBOLKey )   
        GROUP BY  MBOL.Mbolkey,  
               CONVERT(NVARCHAR(8),MBOL.EditDate, 112),                                                       --(Kc01)  
               CONVERT(NVARCHAR(8),DATEADD(DAY, CONVERT(INT, ISNULL(CL.SHORT,0)), MBOL.EditDate), 112),       --(KC01)  
               ORDERS.Storerkey,    
               ORDERS.ConsigneeKey,     
               ORDERS.C_Company,     
               ORDERS.C_Address1,     
               ORDERS.C_Address2,     
               ORDERS.C_Address3,     
               ORDERS.C_Address4,     
               ORDERS.ExternOrderKey,  
               ISNULL(CARRIER.Company, ''),  
               STORER.Contact1, -- June01  
               STORER.Phone1, -- June01  
               STORER.Fax1, -- SOS105609  
               STORER.Email1, -- SOS105609  
               CONVERT(NVARCHAR(4000), STORER.Notes1)       --(Kc01)  
  
        
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
            IF not exists (Select 1  
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
  
            Select @n_grouping = @n_grouping + 1  
            Set    RowCount 0  
     
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