SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: fnc_GetTCPCartonCloseHeader                        */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-04-2012   Shong         AddDate                                   */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetTCPCartonCloseHeader] (@nSerialNo INT)      
RETURNS @tCartonCloseHeader TABLE       
(      
    SerialNo         INT PRIMARY KEY NOT NULL,      
    MessageNum       VARCHAR(8)  NOT NULL,      
    MessageName      VARCHAR(15) NOT NULL,      
    StorerKey        VARCHAR(15) NOT NULL,      
    Facility         VARCHAR( 5) NOT NULL,      
    LPNNo            VARCHAR(20) NOT NULL,      
    MasterLPNNo      VARCHAR(20) NOT NULL,      
    TxCode           VARCHAR( 5) NOT NULL,    
    LastCarton       VARCHAR( 1) NOT NULL,    
    CartonType       VARCHAR(10) NOT NULL,    
    [STATUS]         VARCHAR(1)  NOT NULL,      
    ErrMsg           VARCHAR(400) NOT NULL,      
    AddDate          DATETIME NOT NULL,  
    AddWho           VARCHAR(215) NOT NULL,  
    EditDate         DATETIME NOT NULL,  
    EditWho          VARCHAR(215) NOT NULL  
)      
AS      
BEGIN      
 -- SELECT ALL DATA  
 IF @nSerialNo = 0  
 BEGIN  
   INSERT @tCartonCloseHeader    
     SELECT ti.SerialNo,       
            ti.MessageNum,       
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageName,      
            ISNULL(RTRIM(SubString(ti.[Data],  24,  15)),'') AS StorerKey,      
            ISNULL(RTRIM(SubString(ti.[Data],  39,   5)),'') AS Facility,            
            ISNULL(RTRIM(SubString(ti.[Data],  44,  20)),'') AS LPNNo,        
            ISNULL(RTRIM(SubString(ti.[Data],  64,  20)),'') AS MasterLPNNo,    
            ISNULL(RTRIM(SubString(ti.[Data],  84,   5)),'') AS TXCode,       
            ISNULL(RTRIM(SubString(ti.[Data],  89,   1)),'') AS LastCarton,    
            ISNULL(RTRIM(SubString(ti.[Data],  90,  10)),'') AS CartonType,    
            ti.[Status],   
            ti.ErrMsg,  
            ti.AddDate,   
            ti.AddWho,   
            ti.EditDate,   
            ti.EditWho  
     FROM TCPSocket_INLog ti WITH (NOLOCK)      
     WHERE (Data Like '%CARTONCLOSE%')     
 END  
 ELSE  
 BEGIN  
   INSERT @tCartonCloseHeader    
     SELECT ti.SerialNo,       
            ti.MessageNum,       
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageName,      
            ISNULL(RTRIM(SubString(ti.[Data],  24,  15)),'') AS StorerKey,      
            ISNULL(RTRIM(SubString(ti.[Data],  39,   5)),'') AS Facility,            
            ISNULL(RTRIM(SubString(ti.[Data],  44,  20)),'') AS LPNNo,        
            ISNULL(RTRIM(SubString(ti.[Data],  64,  20)),'') AS MasterLPNNo,    
            ISNULL(RTRIM(SubString(ti.[Data],  84,   5)),'') AS TXCode,       
            ISNULL(RTRIM(SubString(ti.[Data],  89,   1)),'') AS LastCarton,    
            ISNULL(RTRIM(SubString(ti.[Data],  90,  10)),'') AS CartonType,    
            ti.[Status],   
            ti.ErrMsg,  
            ti.AddDate,   
            ti.AddWho,   
            ti.EditDate,   
            ti.EditWho  
     FROM TCPSocket_INLog ti WITH (NOLOCK)      
     WHERE ti.SerialNo = @nSerialNo       
 END   
   RETURN      
END;  

GO