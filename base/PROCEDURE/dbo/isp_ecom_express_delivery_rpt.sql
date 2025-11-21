SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/          
/* Stored Proc: isp_ecom_express_delivery_rpt                              */          
/* Creation Date: 08-OCT-2020                                              */          
/* Copyright: LF Logistics                                                 */          
/* Written by: CSCHONG                                                     */          
/*                                                                         */          
/* Purpose:WMS-15386-【CN】Converse_ecom_express_delivery_list_CR            */          
/*        :                                                                */          
/* Called By: r_dw_ecom_express_delivery_rpt                               */          
/*          :                                                              */          
/* PVCS Version: 1.0                                                       */          
/*                                                                         */          
/* Data Modifications:                                                     */          
/*                                                                         */          
/* Updates:                                                                */          
/* Date         Author     Ver  Purposes                                   */   
/* 2021-Apr-09  CSCHONG    1.1  WMS-16024 PB-Standardize TrackingNo (CS01) */        
/***************************************************************************/          
CREATE PROC [dbo].[isp_ecom_express_delivery_rpt]          
           @c_ContainerKey    NVARCHAR(60),          
           @c_PalletKey       NVARCHAR(60)        
          
AS          
BEGIN          
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF       
                 
   
   DECLARE    
           @n_StartTCnt       INT,  
           @n_Continue        INT,
           @c_SQL             NVARCHAR(4000),        
           @c_SQLSORT         NVARCHAR(4000),        
           @c_SQLJOIN         NVARCHAR(4000),
           @c_condition1      NVARCHAR(150) ,
           @c_condition2      NVARCHAR(150),
           @c_SQLGroup        NVARCHAR(4000),
           @c_SQLOrdBy        NVARCHAR(150),
           @c_ExecArguments   NVARCHAR(4000)   
  
  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
          
     SET @c_SQLJOIN = N' SELECT mbolkey =   MBOL.MbolKey, ' +
                       ' ExternMbolKey  =   MBOL.ExternMbolKey,  ' +
                       ' CtnCaseID      =   COUNT(PAD.CaseId), ' +
                       ' Shipperkey     =   ORD.ShipperKey, ' +
                      -- ' OHUDF04        =   ORD.UserDefine04, ' +    --CS01
                       ' OHUDF04        = ORD.Trackingno, ' +  --CS01
                       ' ExtOrdKey      =   ORD.ExternOrderKey, ' +
                       ' PIWGT          =   PI.Weight  ' +
                       ' FROM CONTAINERDETAIL COD WITH (NOLOCK)  ' +
                       ' JOIN MBOL MBOL WITH (NOLOCK)   ON COD.PalletKey=MBOL.ExternMbolKey ' +
                       ' JOIN MBOLDETAIL MBOLD WITH (NOLOCK)   ON MBOL.MbolKey=MBOLD.MbolKey ' +
                       ' JOIN ORDERS ORD  WITH (NOLOCK)   ON MBOLD.OrderKey=ORD.OrderKey ' +
                       ' JOIN PackHeader PH WITH (NOLOCK)   ON PH.StorerKey=ORD.StorerKey AND PH.OrderKey=ORD.OrderKey ' +
                       ' JOIN PackInfo PI WITH (NOLOCK)   ON PH.PickSlipNo=PI.PickSlipNo ' +
                       ' JOIN PALLETDETAIL PAD  WITH (NOLOCK)  ON COD.PalletKey=PAD.PalletKey ' 

  IF EXISTS (SELECT 1 FROM CONTAINERDETAIL WITH (NOLOCK) WHERE ContainerKey=@c_ContainerKey AND  PalletKey=@c_PalletKey)
  BEGIN
      SET @c_condition1 = N' WHERE COD.ContainerKey=@c_ContainerKey ' + 
                           ' AND COD.PalletKey=@c_PalletKey '
   
  END 
  ELSE IF EXISTS (SELECT 1 FROM CONTAINERDETAIL WITH (NOLOCK) WHERE PalletKey=@c_ContainerKey) 
  BEGIN
     SET @c_condition1 = N' WHERE COD.PalletKey=@c_ContainerKey '
  END
  ELSE IF EXISTS (SELECT 1 FROM MBOL WITH (NOLOCK) WHERE mbolkey=@c_ContainerKey) 
  BEGIN
     SET @c_condition1 = N' WHERE MBOL.mbolkey=@c_ContainerKey '
  END
            --WHERE COD.ContainerKey=@c_ContainerKey
            --AND   COD.PalletKey=@c_PalletKey
  SET @c_SQLGroup=N' GROUP BY  MBOL.MbolKey,MBOL.ExternMbolKey,ORD.ShipperKey,ORD.trackingno,ORD.ExternOrderKey,PI.Weight '   --CS01
  SET @c_SQLOrdBy= N' ORDER BY ORD.ExternOrderKey '

   SET @c_ExecArguments = N'@c_ContainerKey     NVARCHAR(60),'
                        + ' @c_PalletKey        NVARCHAR(60)' 
                           
                       
       
       SET @c_SQL = @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_SQLGroup + CHAR(13) + @c_SQLOrdBy
      
      --PRINT @c_SQL
      
    EXEC sp_executesql   @c_SQL  
                       , @c_ExecArguments  
                       , @c_ContainerKey
                       , @c_PalletKey
          
   WHILE @@TRANCOUNT < @n_StartTCnt          
   BEGIN          
      BEGIN TRAN          
   END          
END -- procedure 

SET QUOTED_IDENTIFIER OFF 

GO