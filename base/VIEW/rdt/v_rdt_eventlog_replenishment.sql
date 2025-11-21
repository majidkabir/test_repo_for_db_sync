SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [RDT].[V_RDT_EventLog_Replenishment]
AS 
SELECT  EventNum     ,
        EventType    ,
        ActionType   ,
        (SELECT RTRIM(Description) FROM dbo.CODELKUP WITH (NOLOCK) 
         WHERE ActionType = Code and ListName = 'RDTACTTYPE') Action_Type,
        EventDateTime,
        UserID       ,
        MobileNo     ,
        FunctionID   ,
        (SELECT DISTINCT RTRIM(Message_Text) FROM RDT.RDTMsg WITH (NOLOCK) 
         WHERE FunctionID = message_id and Lang_Code = 'ENG') Function_Name,
        Facility     ,
        StorerKey    ,
        Location     ,
        ToLocation   ,
        PutawayZone  ,
        PickZone     ,
        ID           ,
        ToID         ,
        SKU          ,
        ComponentSKU ,
        UOM          ,
        QTY          ,
        Lot          ,
        ToLot        ,
        Lottable01   ,
        Lottable02   ,
        Lottable03   ,
        Lottable04   ,
        Lottable05   ,
        RefNo1       ,
        RefNo2       ,
        RefNo3       ,
        RefNo4       ,
        RefNo5       ,
        RowRef       
FROM rdt.rdtSTDEventLog WITH (NOLOCK)
WHERE Eventtype = 5 





GO