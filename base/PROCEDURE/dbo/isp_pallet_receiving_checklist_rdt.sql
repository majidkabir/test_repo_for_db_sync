SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_Pallet_receiving_checklist_rdt                        */              
/* Creation Date: 10-Sep-2019                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-10412 - [CN] Mast_courier_receiving_checkling_list_CR         */
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_pallet_receiving_checklist_rdt                            */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Pallet_receiving_checklist_rdt]             
       (@c_storerkey     NVARCHAR(20) = '',
        @c_Palletkey     NVARCHAR(30) = '' )
          
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @n_Continue        INT = 1,
           @c_Address1        NVARCHAR(50) = '',    
           @c_Company         NVARCHAR(50) = '',
           @c_DeliveryDate    NVARCHAR(10) = '',
           @c_Externorderkey  NVARCHAR(50) = '',
           @c_GetDropID       NVARCHAR(20) = '',
           @c_Type            NVARCHAR(50) = '',
           @c_SKU             NVARCHAR(50) = '',
           @c_Descr           NVARCHAR(50) = '',
           @n_Casecnt         INT = 0,
           @c_C31             NVARCHAR(500) = '',
           @c_C32             NVARCHAR(500) = '',
           @c_C33             NVARCHAR(500) = '',
           @c_C34             NVARCHAR(500) = '',
           @c_C35             NVARCHAR(500) = '',
           @c_RPTLogo         NVARCHAR(500) = '',
           @c_Orderkey        NVARCHAR(10) = '',
           @c_PLTDETUDF02     NVARCHAR(50) = '',
           @c_Courier         NVARCHAR(50) = '', 

           @n_Qty             INT = 0,
           @n_QtyPerCaseCnt   INT = 0,
           @c_Datawindow      NVARCHAR(100) = 'isp_Pallet_receiving_checklist_rdt'


         select @c_PLTDETUDF02 = ISNULL(PLTDET.UserDefine02,'')
         FROM PALLETDETAIL PLTDET WITH (NOLOCK)
         WHERE PLTDET.StorerKey = @c_storerkey
         AND PLTDET.PalletKey = @c_Palletkey
  
      IF ISNULL(@c_PLTDETUDF02,'') <> ''
      BEGIN
        SELECT @c_Courier = ST.company
        FROM STORER ST WITH (NOLOCK)
        WHERE ST.StorerKey = @c_PLTDETUDF02
      END
      
    SELECT DISTINCT PLT.PalletKey as Palletkey,PLTDET.AddDate as AddDate,
    PLTDET.CaseId as caseid, --(20)
    --PLTDET.Qty as Qty,
    1 as Qty,
    @c_Courier as UDF02 --PLTDET.UserDefine02 as UDF02  --(30)
    FROM PALLET PLT WITH (NOLOCK)
    JOIN PALLETDETAIL PLTDET WITH (NOLOCK) ON PLTDET.PalletKey = PLT.PalletKey
    WHERE PLT.StorerKey = @c_storerkey
    AND PLT.PalletKey = @c_Palletkey

               
END

GO