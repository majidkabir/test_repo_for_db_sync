SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PrintDelivery_Summ_03                          */
/* Creation Date:  27-Sep-2011                                          */
/* Copyright: IDS                                                       */
/* Written by:  NJOW                                                    */
/*                                                                      */
/* Purpose:  225979 - CN Umbro Delivery Summary                         */
/*                                                                      */
/*                                                                      */
/* Input Parameters:  @cMBOLKey                                         */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  Report                                               */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: PB - r_dw_delivery_summ_03                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintDelivery_Summ_03] (
       @cMBOLKey       NVARCHAR(10) = '' 
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
       
   /*DECLARE @t_Result Table (
           Mbolkey              NVARCHAR(10),
           StorerKey            NVARCHAR(15),
           C_Company            NVARCHAR(45),
           ExternOrderKey       NVARCHAR(30),
           QTY                  int,
           CartonCnt            int,
   			   Loadkey				      NVARCHAR(10),
			     BuyerPO              NVARCHAR(20))

      INSERT INTO  @t_Result
	      (  Mbolkey,   
	         StorerKey, 
   				 C_Company, 
	         ExternOrderKey,  
				   QTY,  
				   CartonCnt,
    			 Loadkey,
				   BuyerPO)  */
      SELECT MBOL.Mbolkey,
	         ORDERS.Storerkey,  
	         ORDERS.C_Company,   
	         ORDERS.ExternOrderKey,
	         QTY = SUM (ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyPicked + ORDERDETAIL.QtyAllocated ),   
	         CartonCnt = ISNULL(( SELECT COUNT( Distinct PD.PickSlipNo +''+ convert(NVARCHAR(10),PD.CartonNo) )
							             FROM PACKDETAIL PD WITH (NOLOCK)  
							             	   JOIN PACKHEADER PH WITH (NOLOCK) ON ( PH.PickSlipNO  = PD.PickSlipNO )
							                 JOIN ORDERS O WITH (NOLOCK) ON ( PH.LoadKey = O.LoadKey )
							            WHERE O.Mbolkey  = MBOL.Mbolkey  
											    AND  ISNULL(O.c_Company, '') = ISNULL(ORDERS.C_Company, '')), 0) ,
	         ORDERS.Loadkey,
	         ORDERS.BuyerPO    
        FROM ORDERDETAIL WITH (NOLOCK)   
            JOIN ORDERS WITH (NOLOCK) on ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
            JOIN MBOL WITH (NOLOCK) on (ORDERS.Mbolkey = MBOL.Mbolkey)
      WHERE ( MBOL.Mbolkey = @cMBOLKey ) 
   GROUP BY MBOL.Mbolkey,
            ORDERS.Storerkey,  
            ORDERS.C_Company,   
            ORDERS.ExternOrderKey,
    				ORDERS.Loadkey, 
		    		ORDERS.BuyerPO 

/*           
Quit:
   SELECT * FROM @t_Result 
*/
  
END

GO